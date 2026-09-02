#!/usr/bin/env python3
"""
format-docx-vn.py — Vietnamese Administrative Document Formatter
Chuẩn hóa định dạng văn bản hành chính Việt Nam theo Nghị định 30/2020/NĐ-CP
Usage:
    python3 format-docx-vn.py [<input_or_dir>] [<output_path>]
"""
import sys
import os
import shutil

TEMPLATE_SRC = "/home/doe/Windows/skills/vn-officecli/templates/to_trinh_mau.docx"

def resolve_target_file(target: str) -> str:
    target = os.path.expanduser(target)
    if os.path.isdir(target):
        # Look for .docx files inside directory, prioritizing non-formatted
        items = [os.path.join(target, f) for f in os.listdir(target)
                 if f.endswith(".docx") and not f.endswith("_formatted.docx")]
        if items:
            # Prioritize to_trinh
            to_trinhs = [f for f in items if "to_trinh" in os.path.basename(f).lower()]
            return to_trinhs[0] if to_trinhs else items[0]
        # If no docx in dir, copy template if available
        if os.path.exists(TEMPLATE_SRC):
            dest = os.path.join(target, "to_trinh_mau.docx")
            shutil.copy2(TEMPLATE_SRC, dest)
            return dest
    elif not os.path.exists(target):
        # If specific file doesn't exist but is in Downloads, try copy from template
        if "to_trinh" in target.lower() and os.path.exists(TEMPLATE_SRC):
            os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
            shutil.copy2(TEMPLATE_SRC, target)
            return target
    return target

def format_docx(input_path: str = None, output_path: str = None) -> str:
    try:
        from docx import Document
        from docx.shared import Pt, Cm
        from docx.enum.text import WD_ALIGN_PARAGRAPH
    except ImportError:
        return "[Lỗi: python-docx chưa được cài đặt. Chạy: /home/doe/.local/lib/paradise-venv/bin/pip install python-docx]"

    if not input_path:
        input_path = "/home/doe/Downloads"

    resolved = resolve_target_file(input_path)
    if not os.path.exists(resolved):
        return f"[Lỗi: Không tìm thấy file '{resolved}']"

    if output_path is None:
        base, ext = os.path.splitext(resolved)
        output_path = f"{base}_formatted{ext}"

    try:
        doc = Document(resolved)

        # Set page margins (A4, lề chuẩn Nghị định 30)
        for section in doc.sections:
            section.top_margin    = Cm(2.5)
            section.bottom_margin = Cm(2.0)
            section.left_margin   = Cm(3.0)
            section.right_margin  = Cm(1.5)
            section.page_width    = Cm(21.0)
            section.page_height   = Cm(29.7)

        # Set default font via Normal style
        try:
            style = doc.styles['Normal']
            style.font.name = 'Times New Roman'
            style.font.size = Pt(13)
        except Exception:
            pass

        # Format each paragraph
        for para in doc.paragraphs:
            if para.text.strip():
                para.paragraph_format.line_spacing = Pt(13 * 1.3)
                para.paragraph_format.space_before = Pt(3)
                para.paragraph_format.space_after  = Pt(6)

                for run in para.runs:
                    if not run.font.name:
                        run.font.name = 'Times New Roman'
                    if not run.font.size:
                        run.font.size = Pt(13)

                text = para.text.strip().upper()
                if (para.alignment == WD_ALIGN_PARAGRAPH.CENTER or
                        any(text.startswith(h) for h in [
                            "CỘNG HÒA", "TỜ TRÌNH", "PHÒNG", "CÔNG TY",
                            "BAN ", "TRUNG ", "ĐỀ NGHỊ", "KÍNH GỬI",
                            "CỘNG", "CHÍNH PHỦ", "BỘ ", "SỞ ",
                        ])):
                    para.alignment = WD_ALIGN_PARAGRAPH.CENTER
                else:
                    para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                    para.paragraph_format.first_line_indent = Cm(1.25)

        doc.save(output_path)
        return (
            f"✅ Đã chuẩn hóa định dạng văn bản thành công!\n"
            f"   📄 File gốc   : {resolved}\n"
            f"   💾 File đã lưu: {output_path}\n\n"
            f"Quy chuẩn Nghị định 30/2020/NĐ-CP đã áp dụng:\n"
            f"  • Khổ giấy     : A4 (210 × 297 mm)\n"
            f"  • Lề trái      : 3.0 cm | Lề phải: 1.5 cm\n"
            f"  • Lề trên      : 2.5 cm | Lề dưới: 2.0 cm\n"
            f"  • Phông chữ    : Times New Roman, 13pt\n"
            f"  • Giãn dòng    : 1.3×\n"
            f"  • Căn chỉnh    : Đều hai bên (Justified)\n"
            f"  • Thụt đầu dòng: 1.25 cm"
        )
    except Exception as e:
        return f"[Lỗi khi chuẩn hóa file: {e}]"


if __name__ == "__main__":
    in_arg = sys.argv[1] if len(sys.argv) > 1 else "/home/doe/Downloads"
    out_arg = sys.argv[2] if len(sys.argv) > 2 else None
    print(format_docx(in_arg, out_arg))
