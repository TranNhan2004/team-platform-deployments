import secrets
import string

def generate_password(length: int = 20) -> str:
    chars = string.ascii_letters + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))

for _ in range(10):
    print(generate_password())