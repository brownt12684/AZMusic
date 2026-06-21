import sqlite3
from pathlib import Path

def run_migration():
    # Target your specific local SQLite db file path
    db_path = Path("azmusic_server.db")
    
    if not db_path.exists():
        print(f"Database not found at {db_path.absolute()}. Run this from your server root directory.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Define the missing media_assets columns added in the recent asset features
    columns_to_add = [
        ("youtube_video_id", "TEXT"),
        ("thumbnail_url", "TEXT")
    ]
    
    for col_name, col_type in columns_to_add:
        try:
            print(f"Adding column {col_name} to media_assets...")
            cursor.execute(f"ALTER TABLE media_assets ADD COLUMN {col_name} {col_type};")
            print(f"Successfully added {col_name}!")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e).lower():
                print(f"Column {col_name} already exists. Skipping.")
            else:
                print(f"Error adding {col_name}: {e}")
                
    conn.commit()
    conn.close()
    print("Migration sequence completed successfully!")

if __name__ == "__main__":
    run_migration()