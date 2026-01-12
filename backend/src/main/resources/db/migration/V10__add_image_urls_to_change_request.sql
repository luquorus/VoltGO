-- Add image_urls column to change_request table
-- Store array of object keys (MinIO paths) for uploaded images
ALTER TABLE change_request 
ADD COLUMN image_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN change_request.image_urls IS 'Array of MinIO object keys for uploaded station proposal images';

