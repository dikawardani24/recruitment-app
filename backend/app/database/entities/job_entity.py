from uuid import uuid4

class JobEntity:
    def __init__(
        self,
        title: str,
        desc: str,
        req: str,
        status: str,
        created_at: str,
        updated_at: str,
        id: str = str(uuid4()),
        jd_file_path = None
    ):
        self.id = id
        self.title = title
        self.desc = desc
        self.req = req
        self.status = status
        self.created_at = created_at
        self.updated_at = updated_at
        self.jd_file_path = jd_file_path
        pass