"""
Deterministic Sinhala linguistic and Unicode structure validator.
Catches OCR errors, illegal diacritic combinations, ZWJ sequences,
normalization defects, and structured entity regex mismatches.
"""

import re
import unicodedata

# Unicode Constants for Sinhala script (U+0D80 to U+0DFF)
SINHALA_CONSONANTS = set(range(0x0D9A, 0x0DC7))   # ක to ෆ
SINHALA_INDEP_VOWELS = set(range(0x0D85, 0x0D97)) # අ to ඖ
VIRAMA = 0x0DCA                                   # ් (Hal lakuna)
ZWJ = 0x200D                                      # Zero-width joiner
ANUSVARAYA = 0x0D82                               # ං
VISARGAYA = 0x0D83                                # ඃ

# Dependent Vowel Signs (Pili)
# 0x0DCF-0x0DD6: ා ැ ෑ ි ී ු ූ
# 0x0DD8: ෘ
# 0x0DD9-0x0DDE: ෙ ේ ෛ ො ෝ ෞ
# 0x0DF2-0x0DF3: ෲ ෟ
SINHALA_DEP_VOWELS = set(
    list(range(0x0DCF, 0x0DD7)) +
    [0x0DD8, 0x0DD9, 0x0DDA, 0x0DDB, 0x0DDC, 0x0DDD, 0x0DDE, 0x0DF2, 0x0DF3]
)

ALL_DIACRITICS = SINHALA_DEP_VOWELS | {VIRAMA, ANUSVARAYA, VISARGAYA}

# Structured Entity Regexes
REGEX_PHONE = re.compile(r'^(?:\+94|0)\d{2}[-\s]?\d{7}$')
REGEX_DATE = re.compile(r'^(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4})$')
REGEX_AMOUNT = re.compile(r'^(?:Rs\.?|LKR)?\s*[\d,]+(?:\.\d{2})?(?:\/=|-)?$', re.IGNORECASE)
REGEX_NIC = re.compile(r'^(?:\d{9}[VvXx]|\d{12})$')
REGEX_EMAIL = re.compile(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')

# Suspicion regexes (tokens that look like entities but might be corrupted)
LOOKS_LIKE_PHONE = re.compile(r'^(?:\+94|0)\d{1,3}[-\s]?\d{1,9}$')
LOOKS_LIKE_DATE = re.compile(r'^\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}$')
LOOKS_LIKE_NIC = re.compile(r'^\d{8,12}[A-Za-z]?$')
LOOKS_LIKE_EMAIL = re.compile(r'@')
LOOKS_LIKE_AMOUNT = re.compile(r'^(?:Rs|LKR|රු|\/=)', re.IGNORECASE)


def validate_sinhala_sequence(text: str) -> tuple[bool, str]:
    """
    Validates a Sinhala word or phrase against strict Unicode/linguistic rules.
    Returns:
        (is_valid, error_reason)
    """
    if not text:
        return True, ""

    # 1. NFC Normalization check
    if unicodedata.normalize('NFC', text) != text:
        return False, "nfc_normalization_defect"

    chars = list(text)
    n = len(chars)

    # 2. Vowel sign after space or at word start
    first_cp = ord(chars[0])
    if first_cp in ALL_DIACRITICS or first_cp == ZWJ:
        return False, "vowel_or_diacritic_at_start"

    for i in range(n):
        cp = ord(chars[i])

        # Check for space immediately preceding a dependent vowel sign
        if cp in ALL_DIACRITICS and i > 0 and chars[i - 1].isspace():
            return False, "vowel_sign_after_space"

        # 3. Two consecutive dependent vowel signs
        if cp in SINHALA_DEP_VOWELS:
            if i + 1 < n and ord(chars[i + 1]) in SINHALA_DEP_VOWELS:
                return False, "consecutive_vowel_signs"

        # 4. ZWJ validation: must be immediately preceded by VIRAMA (Hal Lakuna)
        if cp == ZWJ:
            if i == 0 or ord(chars[i - 1]) != VIRAMA:
                return False, "zwj_not_after_virama"
            # And MUST be followed by a consonant (forming conjunct: rakaransaya/yansaya/bandi)
            if i + 1 >= n or ord(chars[i + 1]) not in SINHALA_CONSONANTS:
                return False, "zwj_not_followed_by_consonant"

        # 5. Virama validation:
        if cp == VIRAMA:
            # Cannot be followed directly by another dependent vowel (e.g. ් + ා)
            if i + 1 < n and ord(chars[i + 1]) in SINHALA_DEP_VOWELS:
                return False, "virama_followed_by_vowel_sign"
            # If followed by ZWJ, handled above.
            # If followed by another virama (්්)
            if i + 1 < n and ord(chars[i + 1]) == VIRAMA:
                return False, "double_virama"

    return True, ""


def validate_entity_regex(token: str) -> tuple[bool, str]:
    """
    Validates structured tokens (dates, amounts, NICs, phone numbers, emails).
    Returns (is_valid, reason).
    """
    clean = token.strip(" ,.:;()[]{}")
    if not clean:
        return True, ""

    # Email
    if LOOKS_LIKE_EMAIL.search(clean):
        if not REGEX_EMAIL.match(clean):
            return False, "invalid_email_format"
        return True, ""

    # Phone
    if LOOKS_LIKE_PHONE.match(clean):
        if not REGEX_PHONE.match(clean):
            return False, "invalid_phone_format"
        return True, ""

    # NIC
    if LOOKS_LIKE_NIC.match(clean) and (clean.endswith(('V', 'v', 'X', 'x')) or len(clean) == 12):
        if not REGEX_NIC.match(clean):
            return False, "invalid_nic_format"
        return True, ""

    # Date
    if LOOKS_LIKE_DATE.match(clean):
        if not REGEX_DATE.match(clean):
            return False, "invalid_date_format"
        return True, ""

    # Amount
    if LOOKS_LIKE_AMOUNT.search(clean):
        if not REGEX_AMOUNT.match(clean):
            return False, "invalid_amount_format"
        return True, ""

    return True, ""


def inspect_word(word: str) -> dict:
    """
    Performs full validity inspection of a single word.
    """
    res = {
        "text": word,
        "valid": True,
        "reasons": []
    }

    # Sinhala grammar check if word contains any Sinhala chars
    has_sinhala = any(0x0D80 <= ord(c) <= 0x0DFF for c in word)
    if has_sinhala:
        ok, reason = validate_sinhala_sequence(word)
        if not ok:
            res["valid"] = False
            res["reasons"].append(reason)

    # Regex validator check
    ok_reg, reason_reg = validate_entity_regex(word)
    if not ok_reg:
        res["valid"] = False
        res["reasons"].append(reason_reg)

    return res
