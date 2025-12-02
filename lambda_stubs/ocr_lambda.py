import json

# Example AWS Lambda (Python) stub for OCR processing.
# Expects an event with S3 bucket/key for the uploaded ID image.
# In production, this lambda would download the object, call an OCR provider
# (e.g., AWS Textract, Google Vision, or a custom OCR), and return structured data.

def lambda_handler(event, context):
    # event parsing depends on the trigger (API Gateway vs S3 event)
    # Here we assume a simple API Gateway style payload:
    body = event.get('body') or {}
    # Placeholder response
    return {
        'statusCode': 200,
        'body': json.dumps({
            'name': 'Priya Sharma',
            'id_number': 'DL-XYZ-1234',
            'dob': '1992-06-10',
            'confidence': 0.93
        })
    }
