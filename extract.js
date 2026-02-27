const fs = require('fs');
const pdf = require('pdf-parse');
const path = require('path');

const docxPath = path.join(__dirname, 'docx');
const outPath = path.join(__dirname, 'pdf_extracted.txt');

async function extract() {
    const files = fs.readdirSync(docxPath).filter(f => f.endsWith('.pdf'));
    let combinedText = '';

    for (const file of files) {
        combinedText += `\n\n--- Start of ${file} ---\n\n`;
        const dataBuffer = fs.readFileSync(path.join(docxPath, file));
        try {
            const data = await pdf(dataBuffer);
            combinedText += data.text;
        } catch (e) {
            combinedText += `Error extracting ${file}: ${e.message}\n`;
        }
        combinedText += `\n\n--- End of ${file} ---\n\n`;
    }

    fs.writeFileSync(outPath, combinedText);
    console.log('Extraction complete. Saved to pdf_extracted.txt');
}

extract();
