package pe.platter.restaurants.infrastructure;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;

import javax.imageio.ImageIO;

import org.openpdf.text.Document;
import org.openpdf.text.Element;
import org.openpdf.text.Font;
import org.openpdf.text.Image;
import org.openpdf.text.PageSize;
import org.openpdf.text.Paragraph;
import org.openpdf.text.Rectangle;
import org.openpdf.text.pdf.PdfPCell;
import org.openpdf.text.pdf.PdfPTable;
import org.openpdf.text.pdf.PdfWriter;
import org.springframework.stereotype.Component;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageConfig;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

/** Genera QR (PNG) y la PrintableQRTemplate (PDF A4, 4 tarjetas por página) listas para imprenta. */
@Component
public class QrRenderer {

    private static final Color INK = new Color(0x2B, 0x1D, 0x16);

    public byte[] png(String content, int size) {
        try {
            BufferedImage image = MatrixToImageWriter.toBufferedImage(matrix(content, size),
                    new MatrixToImageConfig(INK.getRGB(), Color.WHITE.getRGB()));
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(image, "png", out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public byte[] sheet(String restaurantName, List<Card> cards) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Document document = new Document(PageSize.A4, 28, 28, 28, 28);
        PdfWriter.getInstance(document, out);
        document.open();
        PdfPTable grid = new PdfPTable(2);
        grid.setWidthPercentage(100);
        Font title = new Font(Font.HELVETICA, 16, Font.BOLD, INK);
        Font table = new Font(Font.HELVETICA, 26, Font.BOLD, new Color(0xC2, 0x5B, 0x34));
        Font hint = new Font(Font.HELVETICA, 9, Font.NORMAL, new Color(0x55, 0x48, 0x40));
        for (Card card : cards) {
            PdfPCell cell = new PdfPCell();
            cell.setFixedHeight(380);
            cell.setPadding(14);
            cell.setBorder(Rectangle.BOX);
            cell.setBorderColor(new Color(0xE5, 0xD9, 0xCC));
            cell.addElement(centered(new Paragraph(restaurantName, title)));
            cell.addElement(centered(new Paragraph(card.label(), table)));
            try {
                Image qr = Image.getInstance(png(card.url(), 600));
                qr.scaleAbsolute(190, 190);
                qr.setAlignment(Element.ALIGN_CENTER);
                cell.addElement(qr);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
            cell.addElement(centered(new Paragraph(
                    "Escanea con la cámara de tu celular y mira los platos en tu mesa en Realidad Aumentada.\n"
                            + "Sin descargar apps ni registrarte.", hint)));
            grid.addCell(cell);
        }
        grid.completeRow();
        document.add(grid);
        document.close();
        return out.toByteArray();
    }

    private static Paragraph centered(Paragraph p) {
        p.setAlignment(Element.ALIGN_CENTER);
        p.setSpacingAfter(6);
        return p;
    }

    private static BitMatrix matrix(String content, int size) {
        try {
            return new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, size, size,
                    Map.of(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M, EncodeHintType.MARGIN, 2));
        } catch (WriterException e) {
            throw new IllegalArgumentException("No se pudo generar el QR", e);
        }
    }

    public record Card(String label, String url) {
    }
}
