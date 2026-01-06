
<script>
    function bindExportButton() {
        const exportButton = document.querySelector('.ToolButton.apr-button.Export');
        if (exportButton) {
            exportButton.onclick = async function () {
                console.log('Export triggered');
                const { jsPDF } = window.jspdf;
                const doc = new jsPDF();

                const headers = [];
                const data = [];

                const firstRow = $("div.Container.vpBody table tbody tr:not(.Dummy)").first();
                firstRow.find("td:visible").each(function () {
                    const fieldName = $(this).attr("data-field");
                    headers.push(fieldName || "Column");
                });

                $("div.Container.vpBody table tbody tr:not(.Dummy)").each(function () {
                    const row = [];
                    $(this).find("td:visible").each(function () {
                        const cellText = $(this).find(".display").text().trim();
                        row.push(cellText);
                    });
                    if (row.length > 0) data.push(row);
                });

              
				doc.autoTable({
				    head: [headers],
				    body: data,
				    styles: {
				        fontSize: 8,
				        cellPadding: 4
				    },
				    headStyles: {
				        fillColor: [22, 160, 133], // RGB color (e.g., teal)
				        textColor: 255,            // White text
				        fontStyle: 'bold'
				    },
				    theme: 'grid',
				    margin: { top: 20 }
				});


                doc.save("DynamicGridExport.pdf");
            };
        }
    }

    // Initial binding on page load
    document.addEventListener('DOMContentLoaded', function () {
        bindExportButton();

        // Rebind when profile changes
        document.querySelector('.ProfileSelector')?.addEventListener('change', function () {
            // Wait a bit for grid to re-render
            setTimeout(() => {
                bindExportButton();
            }, 500); // Adjust delay if needed
        });
    });
</script>