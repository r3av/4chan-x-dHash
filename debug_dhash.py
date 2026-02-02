import os
from PIL import Image
import math

def compute_hash(image_path):
    try:
        with Image.open(image_path) as img:
            # Resize to 9x8. Using BILINEAR to approximate canvas default
            # Note: Browser implementations vary, but this is a standard approximation
            img = img.resize((9, 8), Image.Resampling.BILINEAR)
            
            # Get pixel data
            # img.getdata() returns sequence of (r,g,b) tuples
            pixels = list(img.getdata())
            
            hash_str = ''
            hash_index = 0
            current_int = 0
            
            # 8 rows (y), 8 comparisons (x)
            # Image is 9x8, so row size is 9
            width = 9
            
            for y in range(8):
                for x in range(8):
                    # Get pixels at (x, y) and (x+1, y)
                    # Index in flat list = y * width + x
                    idx1 = y * width + x
                    idx2 = y * width + x + 1
                    
                    p1 = pixels[idx1]
                    p2 = pixels[idx2]
                    
                    # Calculate average (simple avg like JS implementation)
                    # Handle RGBA just in case, though JPEGs are RGB
                    r1, g1, b1 = p1[0], p1[1], p1[2]
                    r2, g2, b2 = p2[0], p2[1], p2[2]
                    
                    val1 = (r1 + g1 + b1) / 3.0
                    val2 = (r2 + g2 + b2) / 3.0
                    
                    if val1 > val2:
                        current_int |= (1 << hash_index)
                        
                    hash_index += 1
                    if hash_index == 4:
                        hash_str += format(current_int, 'x')
                        current_int = 0
                        hash_index = 0
            
            return hash_str
    except Exception as e:
        return f"Error: {e}"

def hamming_distance(h1, h2):
    if len(h1) != len(h2):
        return -1
    
    dist = 0
    for i in range(len(h1)):
        v1 = int(h1[i], 16)
        v2 = int(h2[i], 16)
        x = v1 ^ v2
        while x > 0:
            dist += x & 1
            x >>= 1
    return dist

def main():
    file1 = "test images/1770018092150264 (1).jpg"
    file2 = "test images/1770018567426243.jpg"
    
    if not os.path.exists(file1) or not os.path.exists(file2):
        print(f"Error: Test files not found.")
        print(f"Checked: {os.path.abspath(file1)}")
        print(f"Checked: {os.path.abspath(file2)}")
        return

    h1 = compute_hash(file1)
    h2 = compute_hash(file2)
    
    print(f"File 1: {file1}")
    print(f"Hash 1: {h1}")
    print("-" * 20)
    print(f"File 2: {file2}")
    print(f"Hash 2: {h2}")
    print("-" * 20)
    
    if len(h1) == 16 and len(h2) == 16:
        dist = hamming_distance(h1, h2)
        print(f"Hamming Distance: {dist}")
        print(f"Bit Similarity: {((64-dist)/64)*100:.2f}%")
        
        # Binary representation for deeper debug
        b1 = bin(int(h1, 16))[2:].zfill(64)
        b2 = bin(int(h2, 16))[2:].zfill(64)
        print(f"\nBin 1: {b1}")
        print(f"Bin 2: {b2}")
    else:
        print("Hashes invalid length or error occurred.")

if __name__ == "__main__":
    main()
