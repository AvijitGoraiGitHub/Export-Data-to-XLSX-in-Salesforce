public with sharing class ExportToXLSX {

    /**
     * Fetch Account records for UI preview and export
     * cacheable=true improves performance in LWC (uses client-side cache)
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {

        // Simple SOQL query with filter to avoid null-heavy data
        return [
            SELECT Name, BillingState, BillingCity, BillingCountry, Phone, Type
            FROM Account
            WHERE BillingCity != NULL AND BillingState != NULL
            LIMIT 100
        ];
    }

    /**
     * Main method to generate XLSX file
     * Returns Base64 string because LWC cannot directly handle Blob from Apex
     */
    @AuraEnabled
    public static String generateXlsx(List<Account> accounts) {

        // =====================================================
        // STEP 1: Build Sheet Data (Rows + Cells)
        // =====================================================

        // Each entry in this list will represent one <row> in Excel
        List<String> rows = new List<String>();

        // -------------------------------
        // Header Row (Row 1)
        // -------------------------------
        rows.add(
            '<row r="1">' +  // r="1" means Excel row number

            // Each cell uses reference like A1, B1, etc.
            // t="inlineStr" means string stored directly inside XML
            cell('A1','Name') +
            cell('B1','Billing State') +
            cell('C1','Billing City') +
            cell('D1','Billing Country') +
            cell('E1','Phone') +
            cell('F1','Type') +

            '</row>'
        );

        Integer rowNum = 2; // Start from row 2 for actual data

        // -------------------------------
        // Data Rows
        // -------------------------------
        for (Account acc : accounts) {

            rows.add(
                '<row r="' + rowNum + '">' +

                // Map Account fields to Excel columns
                // Order matters → defines column position
                cell('A' + rowNum, acc.Name) +
                cell('B' + rowNum, acc.BillingState) +
                cell('C' + rowNum, acc.BillingCity) +
                cell('D' + rowNum, acc.BillingCountry) +
                cell('E' + rowNum, acc.Phone) +
                cell('F' + rowNum, acc.Type) +

                '</row>'
            );

            rowNum++;
        }

        // Combine all row XML into one string
        String sheetData = String.join(rows, '');

        // =====================================================
        // STEP 2: Worksheet XML (Actual Data Container)
        // =====================================================
        String worksheet =
            '<?xml version="1.0" encoding="UTF-8"?>' +

            // Root element for worksheet
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +

                // sheetData holds all rows
                '<sheetData>' + sheetData + '</sheetData>' +

            '</worksheet>';

        // =====================================================
        // STEP 3: Workbook XML (Defines Sheets)
        // =====================================================
        String workbook =
            '<?xml version="1.0" encoding="UTF-8"?>' +

            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +

                '<sheets>' +

                    // r:id connects this sheet to workbook.xml.rels
                    '<sheet name="Accounts" sheetId="1" r:id="rId1"/>' +

                '</sheets>' +

            '</workbook>';

        // =====================================================
        // STEP 4: Workbook Relationships
        // Maps sheet reference → actual file location
        // =====================================================
        String workbookRels =
            '<?xml version="1.0" encoding="UTF-8"?>' +

            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +

                '<Relationship Id="rId1" ' +
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ' +
                'Target="worksheets/sheet1.xml"/>' +

            '</Relationships>';

        // =====================================================
        // STEP 5: Root Relationships (Entry Point)
        // =====================================================
        String rootRels =
            '<?xml version="1.0" encoding="UTF-8"?>' +

            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +

                // Points Excel to workbook.xml
                '<Relationship Id="rId1" ' +
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" ' +
                'Target="xl/workbook.xml"/>' +

            '</Relationships>';

        // =====================================================
        // STEP 6: Content Types (Mandatory)
        // Defines MIME types for each part
        // =====================================================
        String contentTypes =
            '<?xml version="1.0" encoding="UTF-8"?>' +

            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +

                '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
                '<Default Extension="xml" ContentType="application/xml"/>' +

                '<Override PartName="/xl/workbook.xml" ' +
                'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +

                '<Override PartName="/xl/worksheets/sheet1.xml" ' +
                'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +

            '</Types>';

        // =====================================================
        // STEP 7: ZIP Packaging (XLSX Creation)
        // =====================================================
        Compression.ZipWriter writer = new Compression.ZipWriter();

        // IMPORTANT: Folder structure must be EXACT
        writer.addEntry('[Content_Types].xml', Blob.valueOf(contentTypes));
        writer.addEntry('_rels/.rels', Blob.valueOf(rootRels));
        writer.addEntry('xl/workbook.xml', Blob.valueOf(workbook));
        writer.addEntry('xl/_rels/workbook.xml.rels', Blob.valueOf(workbookRels));
        writer.addEntry('xl/worksheets/sheet1.xml', Blob.valueOf(worksheet));

        // Final XLSX file (ZIP)
        Blob zipBlob = writer.getArchive();

        // Return Base64 for LWC
        return EncodingUtil.base64Encode(zipBlob);
    }

    /**
     * Helper method to create a cell
     */
    private static String cell(String ref, String value) {

        return '<c r="' + ref + '" t="inlineStr">' +
                    '<is>' +
                        '<t>' + escape(value) + '</t>' +
                    '</is>' +
               '</c>';
    }

    /**
     * Escape XML special characters
     * Prevents file corruption
     */
    private static String escape(String val) {

        if (val == null) return '';

        return val.replace('&','&amp;')
                  .replace('<','&lt;')
                  .replace('>','&gt;');
    }
}