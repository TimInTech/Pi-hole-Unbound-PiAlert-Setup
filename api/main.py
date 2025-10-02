"""FastAPI app exposing Pi-hole suite data."""
import os
import sqlite3



def _get_api_key() -> str:
    return os.getenv("SUITE_API_KEY", "")


def get_db() -> Generator[sqlite3.Connection, None, None]:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()



        
    cur = db.execute(
        "SELECT timestamp, client, query, action FROM dns_logs ORDER BY id DESC LIMIT ?",
        (limit,),
    )



@app.get("/leases", dependencies=[Depends(require_key)])
def get_ip_leases(db=Depends(get_db)):
    cur = db.execute("SELECT ip, mac, hostname, lease_start, lease_end FROM ip_leases")
    return [dict(row) for row in cur.fetchall()]



