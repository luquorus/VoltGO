path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'rb') as f:
    raw = f.read()

# Find the line with String baseQuery
idx = raw.find(b'String baseQuery')
print(f'Found at byte offset: {idx}')
print(f'Context: {repr(raw[idx:idx+50])}')

# Also check for swapCte
idx2 = raw.find(b'swapCte')
print(f'swapCte found: {idx2}')
if idx2 != -1:
    print(f'Context: {repr(raw[idx2-50:idx2+50])}')

# Check CRLF vs LF
crlf_count = raw.count(b'\r\n')
lf_count = raw.count(b'\n') - crlf_count
print(f'CRLF: {crlf_count}, LF-only: {lf_count}')

# Check if there are \r characters in the text block delimiter area
text_block_area = raw[raw.find(b'String baseQuery = """'):raw.find(b'String baseQuery = """')+20]
print(f'Text block start: {repr(text_block_area)}')
