from typing import Generic, TypeVar

T = TypeVar("T")

class Page:
    def __init__(self, page: int, page_size: int, last_page: bool, data: list[T]):
        self.page = page
        self.page_size = page_size
        self.last_page = last_page
        self.data = data
        pass