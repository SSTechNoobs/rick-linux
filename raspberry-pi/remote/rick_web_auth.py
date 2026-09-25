import base64
import hashlib
import hmac
import json
from pathlib import Path

from websockify.auth_plugins import AuthenticationError


class FileBasicAuth:
    def __init__(self, src=None):
        self.path = Path(src)

    def demand_auth(self):
        raise AuthenticationError(
            response_code=401,
            response_headers={
                "WWW-Authenticate":
                    'Basic realm="Ricks Hyprland Remote Desktop"'
            },
            response_msg="Authentication required",
        )

    def authenticate(self, headers, target_host, target_port):
        header = headers.get("Authorization")

        if not header or not header.startswith("Basic "):
            self.demand_auth()

        try:
            raw = base64.b64decode(header[6:])
            text = raw.decode("ISO-8859-1")
            username, password = text.split(":", 1)
        except Exception:
            self.demand_auth()

        try:
            data = json.loads(self.path.read_text())

            actual = hashlib.pbkdf2_hmac(
                "sha256",
                password.encode(),
                bytes.fromhex(data["salt"]),
                int(data["iterations"]),
            )

            if (
                hmac.compare_digest(username, data["username"])
                and hmac.compare_digest(
                    actual,
                    bytes.fromhex(data["hash"])
                )
            ):
                return

        except Exception:
            pass

        self.demand_auth()
