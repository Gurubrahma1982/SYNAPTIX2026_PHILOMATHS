const fs = require('fs');
const pdf = require('pdf-parse');

async function test() {
    try {
        const dataBuffer = fs.readFileSync('docx/Candidate_Profile_Module_Document.pdf');
        console.log("pdf is type:", typeof pdf);
        const data = await pdf(dataBuffer);
        console.log(data.text.substring(0, 100));
    } catch (e) {
        console.error("Error:", e);
    }
}
test();
