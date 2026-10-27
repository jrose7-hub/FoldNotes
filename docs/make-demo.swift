// Generates docs/demo.gif: an animation of the Notes sidebar
// (with made-up folders) showing what FoldNotes does when Notes opens.
// It's an illustration drawn in code, not a screen recording.
// Usage: swift docs/make-demo.swift docs/demo.gif

import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Folders (made-up)

final class Nodo {
	let nome: String
	let livello: Int
	var figli: [Nodo] = []
	var apertura: CGFloat = 1 // 1 = open, 0 = closed
	init(_ nome: String, _ livello: Int, _ figli: [Nodo] = []) { self.nome = nome; self.livello = livello; self.figli = figli }
}

let progetti = Nodo("Projects", 2, [Nodo("Website", 3), Nodo("App", 3)])
let salute = Nodo("Health", 2, [Nodo("Workouts", 3), Nodo("Check-ups", 3)])
let lavoro = Nodo("Work", 1, [progetti, Nodo("Meetings", 2)])
let personale = Nodo("Personal", 1, [salute, Nodo("Recipes", 2)])
let viaggi = Nodo("Travel", 1, [Nodo("2025", 2), Nodo("2026", 2)])
let idee = Nodo("Ideas", 1, [Nodo("Books", 2), Nodo("Apps", 2)])
let radice: [Nodo] = [Nodo("All iCloud", 1), Nodo("Notes", 1), lavoro, personale, viaggi, idee, Nodo("Recently Deleted", 1)]

// MARK: - Drawing

let L: CGFloat = 640, A: CGFloat = 520, scala: CGFloat = 1
let sfondo = NSColor(srgbRed: 0.16, green: 0.155, blue: 0.15, alpha: 1)
let barra = NSColor(srgbRed: 0.20, green: 0.19, blue: 0.185, alpha: 1)
let testo = NSColor(white: 0.93, alpha: 1)
let tenue = NSColor(white: 0.55, alpha: 1)
let giallo = NSColor(srgbRed: 0.93, green: 0.70, blue: 0.20, alpha: 1)
let accento = NSColor(srgbRed: 0.93, green: 0.70, blue: 0.20, alpha: 1)

func simbolo(_ nome: String, _ punti: CGFloat, _ colore: NSColor) -> NSImage? {
	guard let s = NSImage(systemSymbolName: nome, accessibilityDescription: nil)?
		.withSymbolConfiguration(.init(pointSize: punti, weight: .regular)) else { return nil }
	let c = s.copy() as! NSImage
	c.lockFocus(); colore.set(); NSRect(origin: .zero, size: c.size).fill(using: .sourceAtop); c.unlockFocus()
	return c
}
let iconaCartella = simbolo("folder", 15, giallo)!
let iconaCestino = simbolo("trash", 14, giallo)!
let freccia = simbolo("chevron.right", 10, tenue)!

func scrivi(_ s: String, _ x: CGFloat, _ y: CGFloat, _ dim: CGFloat, _ peso: NSFont.Weight, _ col: NSColor) {
	NSString(string: s).draw(at: NSPoint(x: x, y: y), withAttributes: [
		.font: NSFont.systemFont(ofSize: dim, weight: peso), .foregroundColor: col])
}

func disegna(_ didascalia: String, _ completato: Bool) -> CGImage {
	let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(L * scala), pixelsHigh: Int(A * scala),
		bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
	rep.size = NSSize(width: L, height: A)
	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
	let ctx = NSGraphicsContext.current!.cgContext

	// window
	NSColor(white: 0.08, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: L, height: A).fill()
	let finestra = NSRect(x: 20, y: 56, width: L - 40, height: A - 76)
	sfondo.setFill(); NSBezierPath(roundedRect: finestra, xRadius: 12, yRadius: 12).fill()
	// sidebar
	let laterale = NSRect(x: finestra.minX, y: finestra.minY, width: 250, height: finestra.height)
	ctx.saveGState()
	NSBezierPath(roundedRect: finestra, xRadius: 12, yRadius: 12).addClip()
	barra.setFill(); laterale.fill()
	// note list on the right (grey lines)
	for i in 0..<6 {
		let y = finestra.maxY - 70 - CGFloat(i) * 58
		NSColor(white: 0.30, alpha: 1).setFill()
		NSBezierPath(roundedRect: NSRect(x: laterale.maxX + 24, y: y, width: 180, height: 10), xRadius: 5, yRadius: 5).fill()
		NSColor(white: 0.22, alpha: 1).setFill()
		NSBezierPath(roundedRect: NSRect(x: laterale.maxX + 24, y: y - 20, width: 260, height: 8), xRadius: 4, yRadius: 4).fill()
	}
	ctx.restoreGState()
	// traffic lights
	for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
		c.setFill(); NSBezierPath(ovalIn: NSRect(x: finestra.minX + 16 + CGFloat(i) * 20, y: finestra.maxY - 24, width: 12, height: 12)).fill()
	}

	// rows
	var y = finestra.maxY - 62
	scrivi("iCloud", laterale.minX + 16, y, 11, .semibold, tenue)
	y -= 8
	let h: CGFloat = 27
	ctx.saveGState()
	NSBezierPath(rect: NSRect(x: laterale.minX, y: finestra.minY + 4, width: laterale.width, height: y - finestra.minY)).addClip()
	func riga(_ n: Nodo, _ fattore: CGFloat) {
		let altezza = h * fattore
		guard altezza > 0.5 else { return }
		y -= altezza
		let alpha = min(1, fattore * 1.4)
		let rientro = laterale.minX + 14 + CGFloat(n.livello - 1) * 16
		ctx.saveGState()
		ctx.setAlpha(alpha)
		NSBezierPath(rect: NSRect(x: laterale.minX, y: y, width: laterale.width, height: altezza)).addClip()
		let base = y + (altezza - h) / 2 + 6
		if !n.figli.isEmpty {
			// arrow: rotates from right (closed) to down (open)
			ctx.saveGState()
			let centro = CGPoint(x: rientro + 4, y: base + 8)
			ctx.translateBy(x: centro.x, y: centro.y)
			ctx.rotate(by: -.pi / 2 * n.apertura)
			freccia.draw(in: NSRect(x: -freccia.size.width / 2, y: -freccia.size.height / 2, width: freccia.size.width, height: freccia.size.height))
			ctx.restoreGState()
		}
		let icona = n.nome == "Recently Deleted" ? iconaCestino : iconaCartella
		icona.draw(in: NSRect(x: rientro + 14, y: base, width: icona.size.width, height: icona.size.height))
		scrivi(n.nome, rientro + 38, base - 1, 13, .regular, testo)
		ctx.restoreGState()
		for f in n.figli { riga(f, fattore * n.apertura) }
	}
	for n in radice { riga(n, 1) }
	ctx.restoreGState()

	// caption at the top
	let col = completato ? accento : NSColor(white: 0.85, alpha: 1)
	let stile = NSMutableParagraphStyle(); stile.alignment = .center
	NSString(string: didascalia).draw(in: NSRect(x: 0, y: 16, width: L, height: 26), withAttributes: [
		.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: col, .paragraphStyle: stile])
	NSGraphicsContext.restoreGraphicsState()
	return rep.cgImage!
}

// MARK: - Animation

var fotogrammi: [(CGImage, Double)] = []
func aggiungi(_ didascalia: String, _ completato: Bool = false, _ durata: Double = 0.04) {
	fotogrammi.append((disegna(didascalia, completato), durata))
}
func ease(_ t: CGFloat) -> CGFloat { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

// like FoldNotes: subfolders first, then the main folders, bottom to top
let fasi: [[Nodo]] = [[salute, progetti], [idee], [viaggi], [personale], [lavoro]]
func reimposta() { for n in [progetti, salute, lavoro, personale, viaggi, idee] { n.apertura = 1 } }

reimposta()
aggiungi("Notes opens: every folder is expanded", false, 1.6)
for fase in fasi {
	for passo in 1...6 {
		let t = ease(CGFloat(passo) / 6)
		for n in fase { n.apertura = 1 - t }
		aggiungi("FoldNotes is collapsing the folders…")
	}
}
aggiungi("Done: all folders collapsed ✓", true, 2.6)

// MARK: - GIF

let uscita = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(uscita as CFURL, UTType.gif.identifier as CFString, fotogrammi.count, nil) else { fatalError() }
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (img, durata) in fotogrammi {
	CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: durata]] as CFDictionary)
}
guard CGImageDestinationFinalize(dest) else { fatalError("GIF not written") }
print("Written \(uscita.path): \(fotogrammi.count) frames")
