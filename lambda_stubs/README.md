This folder contains example AWS Lambda stubs for common verification tasks referenced by the Raahi project.

These are minimal examples for local understanding and must be deployed and secured before production use.

1) ocr_lambda.py - sample Python lambda that would take an image from S3, run OCR, and return extracted fields.
2) verify_id_lambda.py - sample Node.js lambda illustrating basic verification flow with 3rd-party OCR/ID verification.

Deployment notes:
- Use IAM roles with least privilege.
- Protect endpoints with API Gateway + authorizers.
- Do not commit real API keys to the repo.

