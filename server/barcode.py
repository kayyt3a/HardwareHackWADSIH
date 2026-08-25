"""
Barcode/QR decode as a fast, cheap pre-check before falling back to the
vision-language model. If the frame contains a readable barcode and the
product is in Open Food Facts, we can answer near-instantly without a model
call at all — the brief specifically suggests this as the on-device fallback
path; doing it server-side first is the pragmatic hackathon version of the
same idea, with on-device decode (see firmware/src/offline_fallback.h) as
the offline-capable upgrade.
"""
import io
from typing import Optional

import requests
from PIL import Image
from pyzbar.pyzbar import decode as zbar_decode

_OFF_LOOKUP_URL = "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"


def decode(image_bytes: bytes) -> Optional[str]:
    image = Image.open(io.BytesIO(image_bytes))
    results = zbar_decode(image)
    if not results:
        return None
    return results[0].data.decode("utf-8")


def lookup_product(barcode: str) -> Optional[dict]:
    try:
        response = requests.get(_OFF_LOOKUP_URL.format(barcode=barcode), timeout=2)
        response.raise_for_status()
        data = response.json()
    except requests.RequestException:
        return None

    if data.get("status") != 1:
        return None

    product = data.get("product", {})
    return {
        "name": product.get("product_name") or product.get("generic_name"),
        "brand": product.get("brands"),
        "expiry_date": product.get("expiration_date"),  # rarely populated but worth surfacing when present
    }
