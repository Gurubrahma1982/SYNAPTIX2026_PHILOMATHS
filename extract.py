import os
import sys
import subprocess

def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

try:
    import PyPDF2
except ImportError:
    install('PyPDF2')
    import PyPDF2

pdf_dir = 'docx'
with open('pdf_extracted.txt', 'w', encoding='utf-8') as out_file:
    for filename in os.listdir(pdf_dir):
        if filename.endswith('.pdf'):
            out_file.write(f'\n\n--- Start of {filename} ---\n\n')
            try:
                reader = PyPDF2.PdfReader(os.path.join(pdf_dir, filename))
                for page in reader.pages:
                    text = page.extract_text()
                    if text:
                        out_file.write(text + '\n')
            except Exception as e:
                out_file.write(f'Error: {e}\n')
            out_file.write(f'\n\n--- End of {filename} ---\n\n')
print("Done extracting PDFs")
