from __future__ import annotations

from app.core.config import StorageSettings
from app.core.ports import ObjectStorage


class S3Storage(ObjectStorage):
    """AWS S3 adapter implementing ObjectStorage."""

    def __init__(self, settings: StorageSettings) -> None:
        import boto3

        self._bucket = settings.bucket
        self._client = boto3.client("s3", region_name=settings.region)

    async def put(self, key: str, data: bytes, content_type: str) -> None:
        await _run_in_thread(self._client.put_object, Bucket=self._bucket, Key=key, Body=data, ContentType=content_type)

    async def get(self, key: str) -> bytes:
        resp = await _run_in_thread(self._client.get_object, Bucket=self._bucket, Key=key)
        return resp["Body"].read()

    async def delete(self, key: str) -> None:
        await _run_in_thread(self._client.delete_object, Bucket=self._bucket, Key=key)


async def _run_in_thread(fn, *args, **kwargs):  # type: ignore[no-untyped-def]
    import asyncio

    return await asyncio.to_thread(fn, *args, **kwargs)
