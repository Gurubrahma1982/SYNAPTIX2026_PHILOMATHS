const fs = require('fs');
const PDFParser = require('pdf2json');
const path = require('path');

const docxPath = path.join(__dirname, 'docx');
const outPath = path.join(__dirname, 'pdf_extracted.txt');

const files = fs.readdirSync(docxPath).filter(f => f.endsWith('.pdf'));

let currentIndex = 0;
let combinedText = '';

function parseNext() {
    if (currentIndex >= files.length) {
        fs.writeFileSync(outPath, combinedText);
        console.log('Extraction complete. Saved to pdf_extracted.txt');
        return;
    }

    const file = files[currentIndex];
    combinedText += `\n\n--- Start of ${file} ---\n\n`;

    const pdfParser = new PDFParser(this, 1);

    pdfParser.on("pdfParser_dataError", errData => {
        combinedText += `Error extracting ${file}: ${errData.parserError}\n`;
        combinedText += `\n\n--- End of ${file} ---\n\n`;
        currentIndex++;
        parseNext();
    });

    pdfParser.on("pdfParser_dataReady", pdfData => {
        combinedText += pdfParser.getRawTextContent();
        combinedText += `\n\n--- End of ${file} ---\n\n`;
        currentIndex++;
        parseNext();
    });

    pdfParser.loadPDF(path.join(docxPath, file));
}

parseNext();
