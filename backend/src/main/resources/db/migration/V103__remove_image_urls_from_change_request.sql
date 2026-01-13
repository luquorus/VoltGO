-- Remove image_urls column from change_request table
ALTER TABLE change_request 
DROP COLUMN IF EXISTS image_urls;

