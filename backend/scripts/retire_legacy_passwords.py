"""Dry-run by default. Run only after the passwordless backend is deployed."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.supabase import get_client
from services.otp_session import PASSWORD_MIGRATION, retire_legacy_password


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    client = get_client()
    page = 1
    candidates = 0
    while True:
        users = client.auth.admin.list_users(page=page, per_page=100)
        if not users:
            break
        for user in users:
            email = user.email or ''
            if email.endswith(('@wewere.phone', '@wewere.test')) and not (user.app_metadata or {}).get(PASSWORD_MIGRATION):
                candidates += 1
                if args.apply:
                    retire_legacy_password(client, user)
        page += 1
    print(f'{"Migrated" if args.apply else "Would migrate"} {candidates} identities; UUIDs and profile links preserved.')


if __name__ == '__main__':
    main()
