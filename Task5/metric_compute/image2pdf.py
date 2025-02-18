# convert image to pdf
import os
from PyPDF2 import PdfReader, PdfWriter
from PyPDF2.generic import RectangleObject as RO
import pandas as pd

def sort_filenames(filenames, suffix_order):
    def key_function(filename):
        prefix, suffix = filename.rsplit(':', 1) if ':' in filename else (filename, '')
        suffix_index = suffix_order.index(suffix) if suffix in suffix_order else len(suffix_order)
        return (suffix_index, prefix)

    return sorted(filenames, key=key_function)

def merge_pdf(proj_dir,df_sorted_name=None):
    plotWarehouse = os.path.join(proj_dir,'plotWarehouse')
    pdf_files = [i for i in os.listdir(plotWarehouse) if i.endswith(".pdf")]

    # Sort the list by creation time (the first element of each tuple)
    pdf_files.sort()
    if isinstance(df_sorted_name, pd.DataFrame):
        # get list of prefix
        suffix_order = [f'{s}.pdf' for s in df_sorted_name['PointName'].values]
        pdf_files = sort_filenames(pdf_files, suffix_order)

    writer = PdfWriter()
    for i in range(len(pdf_files)):
        pdf_file = os.path.join(plotWarehouse,pdf_files[i])
        if not os.path.exists(pdf_file):
            continue
        page = PdfReader(pdf_file).pages[0]

        # resize mediabox of the last two in the set
        if (i%4)>1:
            page.mediabox = RO([
                page.mediabox.lower_left[0],
                -int(float(page.mediabox.upper_right[1])/11.*3.5),
                page.mediabox.upper_right[0],
                page.mediabox.upper_right[1],
            ])
        
        writer.add_page(page)

    merge_file = os.path.join(proj_dir,"all_plots.pdf")
    if os.path.exists(merge_file):
        os.remove(merge_file)
    with open(merge_file, 'wb') as f:
        writer.write(f)


def png2pdf(proj_dir):
    from PIL import Image
    margin_points = int(300*0.75)  # 0.75 inch margin

    writer = PdfWriter()

    plotWarehouse = os.path.join(proj_dir,'plotWarehouse')
    image_paths = [i for i in os.listdir(plotWarehouse) if i.endswith(".png")]
    image_paths.sort()

    for i, image_path in enumerate(image_paths):
        img = Image.open(os.path.join(plotWarehouse,image_path))

        # Convert image to PDF
        tmp_pdf_path = os.path.join(plotWarehouse,"temp.pdf")
        img.save(tmp_pdf_path, "PDF", resolution=100.0)

        # Add image PDF to the final PDF
        page = PdfReader(tmp_pdf_path).pages[0]

        # Set landscape mode for selected pages
        if (i%4)>1:
            page.mediabox = RO(
                [0, 0-1038, page.mediabox.upper_right[0], page.mediabox.upper_right[1]])

        # Add margins
        page.mediabox = RO([
            page.mediabox.lower_left[0] - margin_points,
            page.mediabox.lower_left[1] - margin_points,
            page.mediabox.upper_right[0] + margin_points,
            page.mediabox.upper_right[1] + margin_points,
        ])

        writer.add_page(page)

        # Remove temporary image PDF
        os.remove(tmp_pdf_path)

    # Write the final PDF
    prefix = os.path.basename(proj_dir).split('_')[0]
    merge_file = os.path.join(proj_dir,f"{prefix}_all_plots.pdf")
    if os.path.exists(merge_file):
        os.remove(merge_file)
    with open(merge_file, "wb") as f:
        writer.write(f)

if __name__ == '__main__':
    proj_dir = os.path.dirname(__file__)
    plotWarehouse = os.path.join(proj_dir,'plotWarehouse')

    # get suffix of the first pdf file
    pdf_file = [i for i in os.listdir(plotWarehouse)[0:10] if i.endswith(".pdf")][0]
    _, suffix = os.listdir(plotWarehouse)[1].rsplit(':', 1) if ':' in pdf_file else (pdf_file, '')

    import LoadData
    conn = LoadData.get_DBconn()
    owinfo = pd.read_sql(LoadData.owinfo_sql, conn)
    conn.close()
    sortedDF = owinfo.sort_values(by=['TargetType','WFCode','PointName'])[['PointName']]
    if suffix[:-4] in sortedDF.PointName.values:
        merge_pdf(proj_dir,sortedDF)
    else:
        merge_pdf(proj_dir)
        
    # png2pdf(proj_dir)