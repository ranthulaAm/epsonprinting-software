"""
Guided Unknown Word Review Manager.
Coordinates human-in-the-loop verification of unknown or uncertain words:
- Evaluates words against confidence thresholds, Sinhala structural grammar,
  lexicons (Sinhala, English, User), regex patterns, and OCR agreement.
- Maintains sensitivity levels: strict (default), balanced, fast.
- Automatically matches and auto-fills identical words via normalized cross-correlation.
- Persists user additions to the user lexicon (data/user_lexicon.json).
- Continually updates the confusion table (data/confusion_matrix.json) from human corrections.
- Exports human-verified line training pairs (.png + .gt.txt) for future tesstrain fine-tuning.
- Serializes and resumes sessions to disk (data/sessions/{job_id}.json).
"""

import os
import io
import json
import copy
import re
import cv2
import numpy as np
from PIL import Image
from typing import Dict, Any, List, Optional, Tuple

from web_preview.pdf_engine.sinhala_validator import inspect_word, check_common_entities
from web_preview.pdf_engine.lexicon import (
    is_known_word,
    add_to_user_lexicon,
    record_correction,
    suggest_candidates,
    clean_word
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
SESSIONS_DIR = os.path.join(DATA_DIR, "sessions")
JOBS_CACHE_DIR = os.path.join(DATA_DIR, "jobs")
TRAINING_DATA_DIR = os.path.join(DATA_DIR, "training_data")

for d in (DATA_DIR, SESSIONS_DIR, JOBS_CACHE_DIR, TRAINING_DATA_DIR):
    os.makedirs(d, exist_ok=True)


class ReviewManager:
    """Manages the interactive unknown-word review queue and auto-fill loop for modernization jobs."""

    def __init__(self):
        self._sessions: Dict[str, Dict[str, Any]] = {}

    def get_or_create_session(self, job_id: str, doc_model: Optional[Dict[str, Any]] = None,
                               orig_images: Optional[List[np.ndarray]] = None,
                               enh_images: Optional[List[np.ndarray]] = None) -> Dict[str, Any]:
        """Loads an existing session from memory/disk or initializes a new one."""
        if job_id in self._sessions:
            sess = self._sessions[job_id]
            if doc_model and (not sess.get("doc_model") or len(sess.get("queue", [])) == 0):
                sess["doc_model"] = doc_model
                self._index_words(sess)
                self._rebuild_queue(sess, sensitivity=sess.get("sensitivity", "strict"))
            return sess

        # Check disk for serialized session
        session_file = os.path.join(SESSIONS_DIR, f"{job_id}.json")
        if os.path.exists(session_file):
            try:
                with open(session_file, "r", encoding="utf-8") as f:
                    sess = json.load(f)
                sess["job_id"] = job_id
                sess.setdefault("history", [])
                sess.setdefault("queue", [])
                sess.setdefault("skipped", [])
                sess.setdefault("auto_applied_records", [])
                self._load_job_images(sess)
                self._index_words(sess)
                self._sessions[job_id] = sess
                return sess
            except Exception as e:
                print(f"[ReviewManager] Failed to load session from disk: {e}")

        # Create new session
        sess = {
            "job_id": job_id,
            "doc_model": doc_model or {},
            "sensitivity": "strict",
            "queue": [],
            "skipped": [],
            "history": [],
            "auto_applied_records": [],
            "total_unknowns": 0,
            "answered_count": 0,
            "page_images_orig": {},
            "page_images_enh": {}
        }

        # Cache images to disk for crisp, on-demand cropping
        job_img_dir = os.path.join(JOBS_CACHE_DIR, job_id)
        os.makedirs(job_img_dir, exist_ok=True)

        if orig_images:
            for p_idx, img in enumerate(orig_images):
                p_num = p_idx + 1
                sess["page_images_orig"][p_num] = img
                cv2.imwrite(os.path.join(job_img_dir, f"page_{p_num}_orig.png"), img)
        if enh_images:
            for p_idx, img in enumerate(enh_images):
                p_num = p_idx + 1
                sess["page_images_enh"][p_num] = img
                cv2.imwrite(os.path.join(job_img_dir, f"page_{p_num}_enh.png"), img)

        if doc_model:
            self._index_words(sess)
            self._rebuild_queue(sess, sensitivity="strict")

        self._sessions[job_id] = sess
        self._save_session(sess)
        return sess

    def register_page_images(self, job_id: str, p_num: int, orig_bgr: np.ndarray, enh_bgr: np.ndarray):
        """Registers page images for a job."""
        sess = self.get_or_create_session(job_id)
        sess["page_images_orig"][p_num] = orig_bgr
        sess["page_images_enh"][p_num] = enh_bgr
        job_img_dir = os.path.join(JOBS_CACHE_DIR, job_id)
        os.makedirs(job_img_dir, exist_ok=True)
        cv2.imwrite(os.path.join(job_img_dir, f"page_{p_num}_orig.png"), orig_bgr)
        cv2.imwrite(os.path.join(job_img_dir, f"page_{p_num}_enh.png"), enh_bgr)

    def _load_job_images(self, sess: Dict[str, Any]):
        """Loads cached original & enhanced images from disk."""
        job_id = sess["job_id"]
        job_img_dir = os.path.join(JOBS_CACHE_DIR, job_id)
        sess["page_images_orig"] = {}
        sess["page_images_enh"] = {}
        if os.path.exists(job_img_dir):
            for fname in os.listdir(job_img_dir):
                if fname.endswith("_orig.png"):
                    p_num = int(fname.split("_")[1])
                    sess["page_images_orig"][p_num] = cv2.imread(os.path.join(job_img_dir, fname))
                elif fname.endswith("_enh.png"):
                    p_num = int(fname.split("_")[1])
                    sess["page_images_enh"][p_num] = cv2.imread(os.path.join(job_img_dir, fname))

    def _index_words(self, sess: Dict[str, Any]):
        """Assigns stable IDs and fast lookup maps for all words in the document model."""
        word_map = {}
        doc_model = sess.get("doc_model", {})
        for p_idx, page in enumerate(doc_model.get("pages", [])):
            p_num = page.get("page_num", p_idx + 1)
            for b_idx, blk in enumerate(page.get("blocks", [])):
                if blk.get("type") in ("heading", "text"):
                    for l_idx, ln in enumerate(blk.get("lines", [])):
                        for w_idx, w in enumerate(ln.get("words", [])):
                            w_id = w.get("id") or f"w_{p_num}_{b_idx}_{l_idx}_{w_idx}"
                            w["id"] = w_id
                            word_map[w_id] = {
                                "page_num": p_num,
                                "b_idx": b_idx,
                                "l_idx": l_idx,
                                "w_idx": w_idx,
                                "line": ln,
                                "word": w
                            }
        sess["word_map"] = word_map

    def _evaluate_word(self, w: Dict[str, Any], sensitivity: str = "strict") -> Tuple[bool, List[str]]:
        """Evaluates whether a word requires guided review."""
        if w.get("human_verified") or w.get("ignored"):
            return False, []

        text = w.get("text", "").strip()
        if not text:
            return False, []

        conf = float(w.get("confidence", 85.0))
        reasons = []

        # 1. Sinhala Unicode validity check
        sin_check = inspect_word(text)
        if not sin_check["valid"]:
            reasons.extend(sin_check["reasons"])

        # 2. Regex check for dates, phones, IDs, emails
        ent_res = check_common_entities(text)
        if ent_res.get("failed_format"):
            reasons.append("Invalid format: " + ent_res["failed_format"])

        # 3. Lexicon check
        clean = clean_word(text)
        known = is_known_word(text)
        if not known and clean and not clean.isdigit() and len(clean) >= 2:
            reasons.append("Not in dictionary")

        # 4. OCR reader disagreement
        doubt_r = w.get("doubt_reason", "")
        if "disagree" in doubt_r or "needs_human" in doubt_r:
            reasons.append("OCR readers disagree")

        # 5. Sensitivity threshold logic
        if sensitivity == "strict":
            if conf < 88.0:
                reasons.append(f"Confidence below strict threshold ({int(conf)}%)")
            is_unknown = len(reasons) > 0
        elif sensitivity == "balanced":
            if conf < 72.0:
                reasons.append(f"Confidence below balanced threshold ({int(conf)}%)")
            is_unknown = (
                not sin_check["valid"] or
                ent_res.get("failed_format") or
                conf < 72.0 or
                ("Not in dictionary" in reasons and conf < 80.0)
            )
        else:  # "fast"
            if conf < 55.0:
                reasons.append(f"Low confidence ({int(conf)}%)")
            is_unknown = (not sin_check["valid"] or conf < 55.0)

        return is_unknown, reasons

    def _rebuild_queue(self, sess: Dict[str, Any], sensitivity: str = "strict"):
        """Re-scans all document words and rebuilds the ordered unknown queue."""
        sess["sensitivity"] = sensitivity
        queue = []
        word_map = sess.get("word_map", {})

        for w_id, entry in word_map.items():
            w = entry["word"]
            is_unk, reasons = self._evaluate_word(w, sensitivity=sensitivity)
            if is_unk:
                w["reasons"] = reasons
                w["doubtful"] = True
                queue.append(w_id)
            else:
                w["doubtful"] = False

        # Rank queue: grammar violations first, then low confidence, then dictionary
        def rank_key(wid):
            w = word_map[wid]["word"]
            r_str = " ".join(w.get("reasons", []))
            score = 0
            if "Invalid" in r_str or "illegal" in r_str: score += 100
            if "disagree" in r_str: score += 50
            score += (100.0 - float(w.get("confidence", 80.0)))
            return -score

        queue.sort(key=rank_key)
        sess["queue"] = queue
        sess["skipped"] = []
        sess["total_unknowns"] = len(queue)
        self._save_session(sess)

    def get_next_unknown(self, job_id: str, sensitivity: Optional[str] = None) -> Dict[str, Any]:
        """Returns the next unknown word card for the guided review loop."""
        sess = self.get_or_create_session(job_id)
        if sensitivity and sensitivity != sess.get("sensitivity"):
            self._rebuild_queue(sess, sensitivity=sensitivity)

        queue = sess.get("queue", [])
        skipped = sess.get("skipped", [])
        word_map = sess.get("word_map", {})

        # Filter out words that might have been answered/auto-applied
        active_queue = [wid for wid in queue if wid in word_map and not word_map[wid]["word"].get("human_verified") and not word_map[wid]["word"].get("ignored") and not word_map[wid]["word"].get("auto_applied")]
        sess["queue"] = active_queue

        if not active_queue and skipped:
            # Re-enqueue skipped words at the end
            active_queue = [wid for wid in skipped if wid in word_map and not word_map[wid]["word"].get("human_verified") and not word_map[wid]["word"].get("ignored") and not word_map[wid]["word"].get("auto_applied")]
            sess["queue"] = active_queue
            sess["skipped"] = []

        remaining = len(active_queue)
        total = max(sess.get("total_unknowns", remaining), remaining)

        if remaining == 0:
            return {
                "is_done": True,
                "remaining": 0,
                "total": total,
                "current_index": total,
                "message": "All words verified!"
            }

        cur_id = active_queue[0]
        entry = word_map[cur_id]
        w = entry["word"]
        ln = entry["line"]
        p_num = entry["page_num"]

        # Ensure suggestions
        text = w.get("text", "")
        alts = w.get("alternatives", [])
        if not alts:
            suggs = suggest_candidates(text, max_candidates=3)
            alts = [{"text": s, "conf": round(w.get("confidence", 75.0) * 0.9, 1)} for s in suggs]

        # Count potential auto-applicable matches
        sim_count = self._count_similar_words(sess, cur_id)

        cur_idx = max(1, total - remaining + 1)
        return {
            "is_done": False,
            "id": cur_id,
            "page": p_num,
            "word_crop_url": f"/api/modernize/{job_id}/crop/word/{cur_id}",
            "line_crop_url": f"/api/modernize/{job_id}/crop/line/{cur_id}",
            "bbox": w.get("bbox", [0, 0, 50, 20]),
            "line_bbox": ln.get("bbox", [0, 0, 200, 30]),
            "ocr_text": text,
            "alternatives": alts,
            "reasons": w.get("reasons", ["Needs review"]),
            "similar_count": sim_count,
            "remaining": remaining,
            "total": total,
            "current_index": cur_idx,
            "sensitivity": sess.get("sensitivity", "strict")
        }

    def answer_word(self, job_id: str, word_id: str, action: str = "accept",
                    text: Optional[str] = None, split_words: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        Processes human answer:
        1. Writes text to document model with confidence 1.0, human_verified=True.
        2. Adds to persistent user lexicon.
        3. Auto-fills identical words across the document via normalized cross-correlation.
        4. Updates confusion matrix with character-level corrections.
        5. Saves verified line training pairs (.png + .gt.txt).
        6. Autosaves session and advances queue.
        """
        sess = self.get_or_create_session(job_id)
        sess.setdefault("history", [])
        sess.setdefault("queue", [])
        sess.setdefault("skipped", [])
        word_map = sess.get("word_map", {})
        if word_id not in word_map:
            raise KeyError(f"Word {word_id} not found in document")

        entry = word_map[word_id]
        w = entry["word"]
        ln = entry["line"]
        p_num = entry["page_num"]

        # Record undo snapshot
        undo_item = {
            "action": action,
            "word_id": word_id,
            "prev_word": copy.deepcopy(w),
            "prev_line_words": copy.deepcopy(ln.get("words", [])),
            "auto_applied": [],
            "prev_queue": list(sess.get("queue", [])),
            "prev_skipped": list(sess.get("skipped", []))
        }

        applied_to = []

        if action == "skip":
            if word_id in sess["queue"]:
                sess["queue"].remove(word_id)
            if word_id not in sess["skipped"]:
                sess["skipped"].append(word_id)
            sess["history"].append(undo_item)
            self._save_session(sess)
            next_c = self.get_next_unknown(job_id)
            return {
                "applied_to": [],
                "remaining": next_c.get("remaining", 0),
                "total": sess.get("total_unknowns", 0),
                "auto_applied_count": 0,
                "next_card": next_c
            }

        if action == "ignore":
            # Mark as noise/image/not a word
            w["ignored"] = True
            w["doubtful"] = False
            if word_id in sess["queue"]:
                sess["queue"].remove(word_id)
            sess["history"].append(undo_item)
            self._save_session(sess)
            next_c = self.get_next_unknown(job_id)
            return {
                "applied_to": [],
                "remaining": next_c.get("remaining", 0),
                "total": sess.get("total_unknowns", 0),
                "auto_applied_count": 0,
                "next_card": next_c
            }

        if action == "merge":
            # Merge with next word on the line
            w_idx = entry["w_idx"]
            all_l_words = ln.get("words", [])
            if w_idx + 1 < len(all_l_words):
                next_w = all_l_words[w_idx + 1]
                w["text"] = (w.get("text", "") + " " + next_w.get("text", "")).strip()
                # Expand bbox
                bx, by, bw, bh = w.get("bbox", [0, 0, 10, 10])
                nx, ny, nw, nh = next_w.get("bbox", [0, 0, 10, 10])
                new_x = min(bx, nx)
                new_y = min(by, ny)
                new_w = max(bx + bw, nx + nw) - new_x
                new_h = max(by + bh, ny + nh) - new_y
                w["bbox"] = [new_x, new_y, new_w, new_h]
                # Remove next_w from queue, skipped and line
                next_wid = next_w.get("id")
                if next_wid in sess.get("queue", []):
                    sess["queue"].remove(next_wid)
                if next_wid in sess.get("skipped", []):
                    sess["skipped"].remove(next_wid)
                all_l_words.pop(w_idx + 1)
                # Re-index
                self._index_words(sess)
                self._save_session(sess)
                next_c = self.get_next_unknown(job_id)
                return {
                    "applied_to": [],
                    "remaining": next_c.get("remaining", 0),
                    "total": sess.get("total_unknowns", 0),
                    "auto_applied_count": 0,
                    "next_card": next_c
                }

        # Handling accept or split (text containing space)
        final_text = (text if text is not None else w.get("text", "")).strip()

        # Space-separated answers trigger word splitting
        if " " in final_text or action == "split":
            parts = final_text.split() if " " in final_text else (split_words or [final_text])
            if len(parts) > 1:
                orig_bbox = w.get("bbox", [0, 0, 60, 20])
                ox, oy, ow, oh = orig_bbox
                tot_chars = max(1, sum(len(p) for p in parts))
                cur_x = ox
                new_words = []
                for p_i, p_str in enumerate(parts):
                    p_w = max(10, int(ow * (len(p_str) / tot_chars)))
                    nw_dict = {
                        "id": f"{word_id}_split_{p_i}",
                        "text": p_str,
                        "bbox": [cur_x, oy, p_w, oh],
                        "confidence": 100.0,
                        "human_verified": True,
                        "doubtful": False,
                        "script": w.get("script", "sin"),
                        "reasons": []
                    }
                    new_words.append(nw_dict)
                    cur_x += p_w + 4
                    add_to_user_lexicon(p_str)

                # Replace in line
                w_idx = entry["w_idx"]
                ln["words"][w_idx:w_idx + 1] = new_words
                self._index_words(sess)
                if word_id in sess["queue"]:
                    sess["queue"].remove(word_id)
                sess["history"].append(undo_item)
                self._save_session(sess)
                next_c = self.get_next_unknown(job_id)
                return {
                    "applied_to": [],
                    "remaining": next_c.get("remaining", 0),
                    "total": sess.get("total_unknowns", 0),
                    "auto_applied_count": 0,
                    "next_card": next_c
                }

        # Standard accept:
        old_ocr_text = w.get("text", "")
        w["text"] = final_text
        w["confidence"] = 100.0
        w["human_verified"] = True
        w["doubtful"] = False
        w["reasons"] = []

        if word_id in sess["queue"]:
            sess["queue"].remove(word_id)
        if word_id in sess["skipped"]:
            sess["skipped"].remove(word_id)

        # 2. Add to persistent user lexicon
        add_to_user_lexicon(final_text)

        # 3. Learn correction pattern
        record_correction(old_ocr_text, final_text)

        # 4. Auto-fill identical words via normalized cross-correlation
        auto_applied_list = self._auto_fill_similar(sess, word_id, final_text)
        applied_to = [rec["id"] for rec in auto_applied_list]
        undo_item["auto_applied"] = auto_applied_list

        sess["history"].append(undo_item)

        # 5. Export training pair for tesstrain if line is fully verified
        self._export_training_pair_if_ready(sess, ln, p_num)

        # 6. Re-evaluate remaining words with new user lexicon
        self._save_session(sess)
        next_c = self.get_next_unknown(job_id)

        return {
            "applied_to": applied_to,
            "remaining": next_c.get("remaining", 0),
            "total": sess.get("total_unknowns", 0),
            "auto_applied_count": len(applied_to),
            "next_card": next_c
        }

    def undo(self, job_id: str) -> Dict[str, Any]:
        """Restores the previous word and brings its card back."""
        sess = self.get_or_create_session(job_id)
        history = sess.get("history", [])
        if not history:
            return {"error": "Nothing to undo", "remaining": len(sess.get("queue", []))}

        last_op = history.pop()
        word_id = last_op["word_id"]
        word_map = sess.get("word_map", {})

        # Restore main word
        if word_id in word_map:
            entry = word_map[word_id]
            entry["word"].clear()
            entry["word"].update(last_op["prev_word"])
            if "prev_line_words" in last_op:
                entry["line"]["words"] = copy.deepcopy(last_op["prev_line_words"])
                self._index_words(sess)

        # Restore auto-applied words
        for auto_rec in last_op.get("auto_applied", []):
            a_id = auto_rec["id"]
            if a_id in word_map:
                w_a = word_map[a_id]["word"]
                w_a["text"] = auto_rec.get("prev_text", w_a.get("text", ""))
                w_a["confidence"] = auto_rec.get("prev_conf", 60.0)
                w_a["human_verified"] = False
                w_a["auto_applied"] = False
                w_a["doubtful"] = True
                if a_id in sess.get("auto_applied_records", []):
                    sess["auto_applied_records"] = [r for r in sess["auto_applied_records"] if r["id"] != a_id]

        sess["queue"] = last_op.get("prev_queue", sess.get("queue", []))
        sess["skipped"] = last_op.get("prev_skipped", sess.get("skipped", []))

        # Put restored word at front of queue
        if word_id not in sess["queue"]:
            sess["queue"].insert(0, word_id)

        self._save_session(sess)
        next_c = self.get_next_unknown(job_id)
        return {
            "restored_id": word_id,
            "remaining": next_c.get("remaining", 0),
            "total": sess.get("total_unknowns", 0),
            "next_card": next_c
        }

    def get_auto_applied(self, job_id: str) -> Dict[str, Any]:
        """Returns the list of words auto-filled by visual template matching."""
        sess = self.get_or_create_session(job_id)
        records = sess.get("auto_applied_records", [])
        return {
            "auto_applied": records,
            "count": len(records)
        }

    def undo_auto_applied_word(self, job_id: str, word_id: str) -> Dict[str, Any]:
        """Reverts a specific auto-applied word back into the unknown queue."""
        sess = self.get_or_create_session(job_id)
        sess.setdefault("history", [])
        sess.setdefault("queue", [])
        sess.setdefault("skipped", [])
        word_map = sess.get("word_map", {})
        if word_id in word_map:
            w = word_map[word_id]["word"]
            w["human_verified"] = False
            w["auto_applied"] = False
            w["doubtful"] = True
            w["confidence"] = 65.0
            if word_id not in sess["queue"]:
                sess["queue"].append(word_id)
            sess["auto_applied_records"] = [r for r in sess.get("auto_applied_records", []) if r["id"] != word_id]
            self._save_session(sess)
            return {"ok": True, "remaining": len(sess["queue"])}
        return {"error": "Word not found"}

    def update_crop(self, job_id: str, word_id: str, bbox: List[int]) -> Dict[str, Any]:
        """Updates word bounding box when user drags handles on line image."""
        sess = self.get_or_create_session(job_id)
        sess.setdefault("history", [])
        sess.setdefault("queue", [])
        sess.setdefault("skipped", [])
        word_map = sess.get("word_map", {})
        if word_id in word_map:
            word_map[word_id]["word"]["bbox"] = [int(v) for v in bbox]
            self._save_session(sess)
            return {"ok": True, "bbox": word_map[word_id]["word"]["bbox"]}
        return {"error": "Word not found"}

    def _auto_fill_similar(self, sess: Dict[str, Any], target_wid: str, answer_text: str,
                           threshold: float = 0.92) -> List[Dict[str, Any]]:
        """
        Finds identical word crops across the document using normalized cross-correlation
        and automatically fills them. Strictly requires similarity >= threshold.
        """
        word_map = sess.get("word_map", {})
        if target_wid not in word_map:
            return []

        target_entry = word_map[target_wid]
        target_crop = self._get_word_crop_mat(sess, target_wid, mode="orig")
        if target_crop is None or target_crop.size == 0 or target_crop.shape[0] < 8 or target_crop.shape[1] < 8:
            return []

        # Target normalized signature: fixed height 32
        t_gray = cv2.cvtColor(target_crop, cv2.COLOR_BGR2GRAY) if len(target_crop.shape) == 3 else target_crop
        if np.std(t_gray) < 4.0:
            return []
        scale = 32.0 / t_gray.shape[0]
        tw = max(16, int(t_gray.shape[1] * scale))
        norm_target = cv2.resize(t_gray, (tw, 32), interpolation=cv2.INTER_AREA)
        norm_target = cv2.normalize(norm_target, None, 0, 255, cv2.NORM_MINMAX)

        target_ratio = target_crop.shape[1] / max(1, target_crop.shape[0])
        applied = []

        # Candidates are unknown words currently in queue or unverified
        candidate_ids = [wid for wid in word_map if wid != target_wid and not word_map[wid]["word"].get("human_verified") and not word_map[wid]["word"].get("ignored")]

        for cid in candidate_ids:
            c_entry = word_map[cid]
            c_word = c_entry["word"]
            c_crop = self._get_word_crop_mat(sess, cid, mode="orig")
            if c_crop is None or c_crop.size == 0 or c_crop.shape[0] < 8 or c_crop.shape[1] < 8:
                continue

            c_ratio = c_crop.shape[1] / max(1, c_crop.shape[0])
            if abs(c_ratio - target_ratio) / max(0.1, target_ratio) > 0.25:
                continue

            c_gray = cv2.cvtColor(c_crop, cv2.COLOR_BGR2GRAY) if len(c_crop.shape) == 3 else c_crop
            if np.std(c_gray) < 4.0:
                continue
            norm_cand = cv2.resize(c_gray, (tw, 32), interpolation=cv2.INTER_AREA)
            norm_cand = cv2.normalize(norm_cand, None, 0, 255, cv2.NORM_MINMAX)

            # Normalized cross-correlation
            try:
                res = cv2.matchTemplate(norm_target, norm_cand, cv2.TM_CCOEFF_NORMED)[0][0]
                similarity = float(res)
            except Exception:
                similarity = 0.0

            if similarity >= threshold:
                prev_text = c_word.get("text", "")
                prev_conf = c_word.get("confidence", 70.0)
                c_word["text"] = answer_text
                c_word["confidence"] = 98.0
                c_word["auto_applied"] = True
                c_word["doubtful"] = False
                c_word["reasons"] = []

                if cid in sess["queue"]:
                    sess["queue"].remove(cid)
                if cid in sess["skipped"]:
                    sess["skipped"].remove(cid)

                record = {
                    "id": cid,
                    "from_id": target_wid,
                    "similarity": round(similarity, 3),
                    "text": answer_text,
                    "prev_text": prev_text,
                    "prev_conf": prev_conf,
                    "page": c_entry["page_num"],
                    "word_crop_url": f"/api/modernize/{sess['job_id']}/crop/word/{cid}"
                }
                applied.append(record)
                sess.setdefault("auto_applied_records", []).append(record)

        return applied

    def _count_similar_words(self, sess: Dict[str, Any], target_wid: str, threshold: float = 0.92) -> int:
        """Counts how many other words in the document visually match the target crop."""
        word_map = sess.get("word_map", {})
        if target_wid not in word_map:
            return 0
        target_crop = self._get_word_crop_mat(sess, target_wid, mode="orig")
        if target_crop is None or target_crop.size == 0 or target_crop.shape[0] < 8:
            return 0

        t_gray = cv2.cvtColor(target_crop, cv2.COLOR_BGR2GRAY) if len(target_crop.shape) == 3 else target_crop
        scale = 32.0 / t_gray.shape[0]
        tw = max(16, int(t_gray.shape[1] * scale))
        norm_target = cv2.resize(t_gray, (tw, 32), interpolation=cv2.INTER_AREA)
        norm_target = cv2.normalize(norm_target, None, 0, 255, cv2.NORM_MINMAX)
        target_ratio = target_crop.shape[1] / max(1, target_crop.shape[0])

        count = 0
        for wid, entry in word_map.items():
            if wid == target_wid or entry["word"].get("human_verified") or entry["word"].get("ignored"):
                continue
            c_crop = self._get_word_crop_mat(sess, wid, mode="orig")
            if c_crop is None or c_crop.size == 0 or c_crop.shape[0] < 8:
                continue
            c_ratio = c_crop.shape[1] / max(1, c_crop.shape[0])
            if abs(c_ratio - target_ratio) / max(0.1, target_ratio) > 0.25:
                continue
            c_gray = cv2.cvtColor(c_crop, cv2.COLOR_BGR2GRAY) if len(c_crop.shape) == 3 else c_crop
            if np.std(c_gray) < 4.0:
                continue
            norm_cand = cv2.resize(c_gray, (tw, 32), interpolation=cv2.INTER_AREA)
            norm_cand = cv2.normalize(norm_cand, None, 0, 255, cv2.NORM_MINMAX)
            try:
                res = cv2.matchTemplate(norm_target, norm_cand, cv2.TM_CCOEFF_NORMED)[0][0]
                if float(res) >= threshold:
                    count += 1
            except Exception:
                pass
        return count

    def _get_word_crop_mat(self, sess: Dict[str, Any], word_id: str, mode: str = "orig") -> Optional[np.ndarray]:
        """Crops word bounding box from page matrix."""
        word_map = sess.get("word_map", {})
        if word_id not in word_map:
            return None
        entry = word_map[word_id]
        p_num = entry["page_num"]
        pages = sess.get("page_images_enh" if mode == "enh" else "page_images_orig", {})
        page_img = pages.get(p_num)
        if page_img is None:
            # Try reloading from disk
            job_id = sess["job_id"]
            fname = f"page_{p_num}_{'enh' if mode == 'enh' else 'orig'}.png"
            fpath = os.path.join(JOBS_CACHE_DIR, job_id, fname)
            if os.path.exists(fpath):
                page_img = cv2.imread(fpath)
                pages[p_num] = page_img
        if page_img is None:
            return None

        ln_bbox = entry["line"].get("bbox", [0, 0, page_img.shape[1], page_img.shape[0]])
        lx, ly, lw, lh = ln_bbox
        w_bbox = entry["word"].get("bbox", [0, 0, lw, lh])
        wx, wy, ww, wh = w_bbox

        # Page coordinates
        abs_x = max(0, lx + wx - 2)
        abs_y = max(0, ly + wy - 2)
        abs_w = min(page_img.shape[1] - abs_x, ww + 4)
        abs_h = min(page_img.shape[0] - abs_y, wh + 4)

        if abs_w <= 0 or abs_h <= 0:
            return None
        return page_img[abs_y:abs_y + abs_h, abs_x:abs_x + abs_w]

    def _get_line_crop_mat(self, sess: Dict[str, Any], word_id: str, mode: str = "orig") -> Optional[np.ndarray]:
        """Crops line bounding box from page matrix."""
        word_map = sess.get("word_map", {})
        if word_id not in word_map:
            return None
        entry = word_map[word_id]
        p_num = entry["page_num"]
        pages = sess.get("page_images_enh" if mode == "enh" else "page_images_orig", {})
        page_img = pages.get(p_num)
        if page_img is None:
            job_id = sess["job_id"]
            fname = f"page_{p_num}_{'enh' if mode == 'enh' else 'orig'}.png"
            fpath = os.path.join(JOBS_CACHE_DIR, job_id, fname)
            if os.path.exists(fpath):
                page_img = cv2.imread(fpath)
                pages[p_num] = page_img
        if page_img is None:
            return None

        lx, ly, lw, lh = entry["line"].get("bbox", [0, 0, page_img.shape[1], page_img.shape[0]])
        abs_x = max(0, lx - 4)
        abs_y = max(0, ly - 4)
        abs_w = min(page_img.shape[1] - abs_x, lw + 8)
        abs_h = min(page_img.shape[0] - abs_y, lh + 8)

        if abs_w <= 0 or abs_h <= 0:
            return None
        return page_img[abs_y:abs_y + abs_h, abs_x:abs_x + abs_w]

    def get_word_crop_png(self, job_id: str, word_id: str, mode: str = "orig") -> Optional[bytes]:
        """Returns PNG bytes of the enlarged word crop."""
        sess = self.get_or_create_session(job_id)
        mat = self._get_word_crop_mat(sess, word_id, mode=mode)
        if mat is None:
            # Fallback 100x40 placeholder
            mat = np.ones((40, 100, 3), dtype=np.uint8) * 240
        # Enlarge 3x for crisp review display
        h, w = mat.shape[:2]
        if h > 0 and w > 0:
            enlarged = cv2.resize(mat, (w * 3, h * 3), interpolation=cv2.INTER_CUBIC)
        else:
            enlarged = mat
        ret, buf = cv2.imencode(".png", enlarged)
        return buf.tobytes() if ret else None

    def get_line_crop_png(self, job_id: str, word_id: str, mode: str = "orig") -> Optional[bytes]:
        """Returns PNG bytes of the line crop."""
        sess = self.get_or_create_session(job_id)
        mat = self._get_line_crop_mat(sess, word_id, mode=mode)
        if mat is None:
            mat = np.ones((40, 300, 3), dtype=np.uint8) * 240
        ret, buf = cv2.imencode(".png", mat)
        return buf.tobytes() if ret else None

    def _export_training_pair_if_ready(self, sess: Dict[str, Any], line: Dict[str, Any], p_num: int):
        """
        Saves line crop image + final UTF-8 text as a training pair in Tesseract ground-truth format:
        <dir>/pair_{job_id}_p{page}_l{l_idx}.png and .gt.txt
        """
        try:
            words = line.get("words", [])
            if not words or not all(w.get("human_verified") or w.get("confidence", 0) >= 90 for w in words):
                return

            line_text = " ".join(w.get("text", "").strip() for w in words if w.get("text") and not w.get("ignored")).strip()
            if not line_text or len(line_text) < 3:
                return

            w_first = words[0]
            mat = self._get_line_crop_mat(sess, w_first.get("id"), mode="orig")
            if mat is None or mat.size == 0:
                return

            job_id = sess["job_id"]
            l_idx = line.get("line_idx", 0)
            base_name = f"pair_{job_id}_p{p_num}_l{l_idx}"
            png_path = os.path.join(TRAINING_DATA_DIR, f"{base_name}.png")
            gt_path = os.path.join(TRAINING_DATA_DIR, f"{base_name}.gt.txt")

            cv2.imwrite(png_path, mat)
            with open(gt_path, "w", encoding="utf-8") as f:
                f.write(line_text + "\n")
        except Exception as e:
            print(f"[ReviewManager] Error saving training pair: {e}")

    def _save_session(self, sess: Dict[str, Any]):
        """Persists the session JSON to disk for resume capability."""
        job_id = sess["job_id"]
        session_file = os.path.join(SESSIONS_DIR, f"{job_id}.json")
        try:
            # Make a lightweight serializable copy
            serializable = {
                "job_id": job_id,
                "doc_model": sess.get("doc_model", {}),
                "sensitivity": sess.get("sensitivity", "strict"),
                "queue": sess.get("queue", []),
                "skipped": sess.get("skipped", []),
                "total_unknowns": sess.get("total_unknowns", 0),
                "auto_applied_records": sess.get("auto_applied_records", [])
            }
            with open(session_file, "w", encoding="utf-8") as f:
                json.dump(serializable, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[ReviewManager] Failed to persist session: {e}")


# Global review manager singleton
REVIEW_MANAGER = ReviewManager()
