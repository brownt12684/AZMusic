import asyncio
from server.database import get_engine
from server.models.orm import Piece

async def main():
    engine = await get_engine()
    async with engine.connect() as conn:
        result = await conn.execute(Piece.__table__.select())
        rows = result.fetchall()
        print(f"Pieces in DB: {len(rows)}")
        for r in rows[:10]:
            print(f"  {r.id}: {r.title}")

asyncio.run(main())
