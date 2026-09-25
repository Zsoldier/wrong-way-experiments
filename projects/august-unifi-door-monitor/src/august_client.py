"""Thin wrapper around the `yalexs` library for polling August/Yale lock + Doorsense state.

`yalexs` is the same async library used by Home Assistant's official August/Yale integration:
https://github.com/Yale-Libs/yalexs
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

from yalexs.api_async import ApiAsync
from yalexs.authenticator_async import AuthenticatorAsync, AuthenticationState

log = logging.getLogger(__name__)


@dataclass
class LockState:
    """Point-in-time snapshot of a single August lock's reported state."""

    lock_name: str
    is_locked: Optional[bool]   # None if unknown/unreachable
    is_door_closed: Optional[bool]  # None if lock has no Doorsense or state unknown


class AugustClient:
    """Authenticates once, then polls a named lock's status on demand."""

    def __init__(
        self,
        login_method: str,
        username: str,
        password: str,
        lock_name: str,
        install_id: Optional[str] = None,
        token_cache_file: str = "august_token_cache.json",
    ) -> None:
        self._api = ApiAsync()
        self._authenticator = AuthenticatorAsync(
            self._api,
            login_method,
            username,
            password,
            install_id=install_id,
            access_token_cache_file=token_cache_file,
        )
        self._lock_name = lock_name
        self._lock_id: Optional[str] = None
        self._authenticated = False

    async def authenticate(self) -> None:
        """Runs the yalexs OAuth flow. May prompt for a verification code on first run."""
        state = await self._authenticator.async_authenticate()
        if state.state == AuthenticationState.VERIFICATION_CODE_REQUIRED:
            await self._authenticator.async_send_verification_code()
            code = input(f"Enter the verification code sent to {self._authenticator.login_method}: ")
            await self._authenticator.async_validate_verification_code(code)
            state = await self._authenticator.async_authenticate()
        self._authenticated = state.state == AuthenticationState.AUTHENTICATED
        if not self._authenticated:
            raise RuntimeError(f"August authentication failed: {state.state}")
        log.info("Authenticated with August cloud API")

    async def _resolve_lock_id(self) -> str:
        if self._lock_id:
            return self._lock_id
        locks = await self._api.async_get_locks(self._authenticator.access_token)
        for lock in locks:
            if lock.device_name == self._lock_name:
                self._lock_id = lock.device_id
                return self._lock_id
        raise LookupError(f"No lock named '{self._lock_name}' found on this August account")

    async def get_state(self) -> LockState:
        """Fetches current lock + Doorsense state. Raises on transport/auth errors so the
        caller's polling loop can apply backoff."""
        if not self._authenticated:
            await self.authenticate()

        lock_id = await self._resolve_lock_id()
        status = await self._api.async_get_lock_detail(self._authenticator.access_token, lock_id)

        is_locked = status.lock_status.name.lower() == "locked" if status.lock_status else None
        is_door_closed = None
        if status.door_state is not None:
            is_door_closed = status.door_state.name.lower() == "closed"

        return LockState(
            lock_name=self._lock_name,
            is_locked=is_locked,
            is_door_closed=is_door_closed,
        )

    async def close(self) -> None:
        await self._api.async_close_http_session()
