#!/usr/bin/env python3
"""
Simple script to download the latest CSV from Petfinder-Database-Distributor API
and save it to pets.csv in the project root.
"""

import os
import sys
import requests

# API configuration
BASE_URL = "https://petfinder-database-distributor.onrender.com"
API_KEY = "3h4hdfbhdfesnfsd2439DSFNUIFGSDBJHF"

def download_csv():
    """Download CSV and save to pets.csv"""
    try:
        print("Downloading latest CSV from API...")
        
        # Make request to API
        headers = {
            "X-API-Key": API_KEY
        }
        
        response = requests.get(f"{BASE_URL}/pets.csv", headers=headers, stream=True)
        response.raise_for_status()
        
        # Get the project root (parent of server directory)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        csv_path = os.path.join(project_root, "pets.csv")
        
        # Download and write CSV
        total_size = 0
        with open(csv_path, 'w', encoding='utf-8') as f:
            for chunk in response.iter_content(chunk_size=8192, decode_unicode=True):
                if chunk:
                    f.write(chunk)
                    total_size += len(chunk.encode('utf-8'))
        
        # Get file stats
        file_size_mb = total_size / (1024 * 1024)
        
        print(f"✓ CSV downloaded successfully!")
        print(f"  File: {csv_path}")
        print(f"  Size: {file_size_mb:.2f} MB")
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"✗ Error downloading CSV: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"  Status code: {e.response.status_code}")
            print(f"  Response: {e.response.text[:200]}")
        return False
    except Exception as e:
        print(f"✗ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    success = download_csv()
    sys.exit(0 if success else 1)

