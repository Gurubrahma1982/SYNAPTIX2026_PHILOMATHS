const fs = require('fs');
const path = require('path');
const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');

const docxPath = path.join(__dirname, 'docx');
const outPath = path.join(__dirname, 'pdf_extracted.txt');

async function extract() {
    const files = fs.readdirSync(docxPath).filter(f => f.endsWith('.pdf'));
    let combinedText = '';

    for (const file of files) {
        combinedText += `\n\n--- Start of ${file} ---\n\n`;
        const filePath = path.join(docxPath, file);
        const data = new Uint8Array(fs.readFileSync(filePath));

        try {
            const loadingTask = pdfjsLib.getDocument({ data });
            const pdfDocument = await loadingTask.promise;

            for (let i = 1; i <= pdfDocument.numPages; i++) {
                const page = await pdfDocument.getPage(i);
                const textContent = await page.getTextContent();
                const textItems = textContent.items.map(item => item.str);
                combinedText += textItems.join(' ') + '\n';
            }
        } catch (e) {
            combinedText += `Error extracting ${file}: ${e.message}\n`;
        }
        combinedText += `\n\n--- End of ${file} ---\n\n`;
    }

    fs.writeFileSync(outPath, combinedText);
    console.log('Extraction complete. Saved to pdf_extracted.txt');
}

extract();
