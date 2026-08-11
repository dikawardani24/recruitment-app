from app.domain.candidate import Candidate
from app.domain.page import Page
from app.repository.cv_repository import CvRepository


class SearchCandidates:
    def __init__(self, cv_repo: CvRepository):
        self.cv_repo = cv_repo

    async def execute(self, keyword: str, page: int, page_size: int) -> dict:
        result: Page[Candidate] = await self.cv_repo.search(
            keyword=keyword, page=page, page_size=page_size
        )

        candidates = [candidate.to_json() for candidate in result.data]

        return {
            "count": len(candidates),
            "candidates": candidates,
            "meta": {
                "page": page,
                "limit": page_size,
                "has_more": not result.last_page,
            },
        }
