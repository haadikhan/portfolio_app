const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

async function main() {
  const puppeteer = require("puppeteer");
  const dir = __dirname;
  const files = [
    "investor_tutorial_brief.html",
    "admin_tutorial_brief.html",
  ];

  const browser = await puppeteer.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });

  try {
    for (const file of files) {
      const htmlPath = path.join(dir, file);
      const pdfPath = path.join(dir, file.replace(/\.html$/, ".pdf"));
      const page = await browser.newPage();
      await page.goto(pathToFileURL(htmlPath).href, {
        waitUntil: "networkidle0",
        timeout: 120000,
      });
      // Allow Google Fonts (Urdu) to settle
      await new Promise((r) => setTimeout(r, 1500));
      await page.pdf({
        path: pdfPath,
        format: "A4",
        printBackground: true,
        margin: { top: "14mm", bottom: "14mm", left: "12mm", right: "12mm" },
      });
      await page.close();
      const size = fs.statSync(pdfPath).size;
      console.log(`Wrote ${pdfPath} (${size} bytes)`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
