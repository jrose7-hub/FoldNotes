// ComprimiNote: collapses the folders in the Notes sidebar when Notes opens.
//
// When it acts: only when Notes opens (macOS event, no polling, no timer).
// What it does: in the Notes window it looks only at the sidebar; it keeps the accounts
// (iCloud, Sul mio Mac…) open and collapses folders and subfolders by pressing their arrows,
// just like a click, so Notes stays in sync (no flicker on rename).
// It doesn't read the notes' content or the folder names.
// It writes a line to ~/Library/Application Support/ComprimiNote/log.txt. No network, no shell.
// It only acts on the real Notes, signed by Apple.

import Cocoa
import ApplicationServices
import Security

let notesID = "com.apple.Notes"
let livelloMinimo = 1 // 0 = accounts (kept open), 1 and up = folders (collapsed)

// MARK: - Log

let cartellaLog = FileManager.default.homeDirectoryForCurrentUser
	.appendingPathComponent("Library/Application Support/ComprimiNote")

func scrivi(_ testo: String) {
	let f = DateFormatter()
	f.dateFormat = "HH:mm:ss"
	let riga = "\(f.string(from: Date())) \(testo)\n"
	try? FileManager.default.createDirectory(at: cartellaLog, withIntermediateDirectories: true)
	let percorso = cartellaLog.appendingPathComponent("log.txt").path
	// O_NOFOLLOW: if someone replaces log.txt with a link to another file, it doesn't write there
	let fd = open(percorso, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0o600)
	guard fd >= 0 else { return }
	defer { close(fd) }
	let dati = Array(riga.utf8)
	_ = dati.withUnsafeBufferPointer { write(fd, $0.baseAddress, $0.count) }
}

// MARK: - Notes check

/// Is it really Apple's Notes? Any app can call itself "com.apple.Notes":
/// only the one signed by Apple with that identifier counts.
func eNoteAutentica(_ pid: pid_t) -> Bool {
	var codice: SecCode?
	guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &codice) == errSecSuccess,
		let codice else { return false }
	var requisito: SecRequirement?
	guard SecRequirementCreateWithString("anchor apple and identifier \"com.apple.Notes\"" as CFString, [], &requisito) == errSecSuccess,
		let requisito else { return false }
	return SecCodeCheckValidity(codice, [], requisito) == errSecSuccess
}

// MARK: - Measuring

/// Counts the questions to Notes and how long they take, so the log shows where the time goes.
final class Misura {
	var chiamate = 0
	var totale: Double = 0
	var massimo: Double = 0
	func azzera() { chiamate = 0; totale = 0; massimo = 0 }
	func conta<T>(_ f: () -> T) -> T {
		let t0 = DispatchTime.now().uptimeNanoseconds
		let r = f()
		let dt = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
		chiamate += 1; totale += dt; massimo = max(massimo, dt)
		return r
	}
	var riassunto: String { "\(chiamate) questions to Notes, \(Int(totale)) ms total, slowest \(Int(massimo)) ms" }
}
let misura = Misura()

// MARK: - Accessibility

func attributo(_ el: AXUIElement, _ nome: String) -> AnyObject? {
	var valore: AnyObject?
	return misura.conta { AXUIElementCopyAttributeValue(el, nome as CFString, &valore) } == .success ? valore : nil
}

/// Several attributes of the same element with a single question to Notes.
/// Missing attributes come back as nil.
func attributi(_ el: AXUIElement, _ nomi: [String]) -> [AnyObject?] {
	var valori: CFArray?
	guard misura.conta({ AXUIElementCopyMultipleAttributeValues(el, nomi as CFArray, [], &valori) }) == .success,
		let v = valori as? [AnyObject], v.count == nomi.count else { return Array(repeating: nil, count: nomi.count) }
	return v.map { CFGetTypeID($0) == AXValueGetTypeID() && AXValueGetType($0 as! AXValue) == .axError ? nil : $0 }
}

func elemento(_ v: AnyObject?) -> AXUIElement? {
	guard let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
	return (v as! AXUIElement)
}

func punto(_ v: AnyObject?) -> CGPoint? {
	guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
	var r = CGPoint.zero
	return AXValueGetValue(v as! AXValue, .cgPoint, &r) ? r : nil
}

func dimensione(_ v: AnyObject?) -> CGSize? {
	guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
	var r = CGSize.zero
	return AXValueGetValue(v as! AXValue, .cgSize, &r) ? r : nil
}

/// Fast way to the sidebar: asks Notes which element is at a point on the left
/// of the window (one question) and walks up to the list (3-4 questions).
func trovaBarraVeloce(_ app: AXUIElement) -> AXUIElement? {
	guard let finestre = attributo(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
	for finestra in finestre {
		let v = attributi(finestra, [kAXPositionAttribute, kAXSizeAttribute])
		guard let pos = punto(v[0]), let dim = dimensione(v[1]) else { continue }
		for frazione in [0.35, 0.55, 0.2] {
			var trovato: AXUIElement?
			let x = Float(pos.x + 45), y = Float(pos.y + dim.height * frazione)
			guard misura.conta({ AXUIElementCopyElementAtPosition(app, x, y, &trovato) }) == .success,
				var attuale = trovato else { continue }
			for _ in 0..<8 {
				let r = attributi(attuale, [kAXRoleAttribute, kAXParentAttribute])
				if r[0] as? String == "AXOutline" { return attuale }
				guard let genitore = elemento(r[1]) else { break }
				attuale = genitore
			}
		}
	}
	return nil
}

/// Slow way, if the fast one fails (e.g. a window covering the sidebar):
/// level-by-level search for the first AXOutline, without going inside lists,
/// tables or the note text.
func trovaBarraCompleta(_ app: AXUIElement) -> AXUIElement? {
	let daSaltare: Set<String> = ["AXTable", "AXList", "AXTextArea", "AXWebArea", "AXCollection",
		"AXToolbar", "AXButton", "AXStaticText", "AXImage", "AXTextField", "AXScrollBar"]
	guard let finestre = attributo(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
	for finestra in finestre {
		var livello = [finestra]
		for _ in 0..<10 {
			var prossimo: [AXUIElement] = []
			for el in livello {
				for figlio in (attributo(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
					let ruolo = attributo(figlio, kAXRoleAttribute) as? String ?? ""
					if ruolo == "AXOutline" { return figlio }
					if !daSaltare.contains(ruolo) { prossimo.append(figlio) }
				}
			}
			if prossimo.isEmpty { break }
			livello = prossimo
		}
	}
	return nil
}

/// The arrow of a row: the row's cell (already read together with the state)
/// → its elements → the first one that's an arrow.
func triangolo(_ celle: [AXUIElement]) -> AXUIElement? {
	for cella in celle {
		for figlio in (attributo(cella, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
			if attributo(figlio, kAXRoleAttribute) as? String == "AXDisclosureTriangle" { return figlio }
		}
	}
	return nil
}

// MARK: - Collapsing

struct Esito { let righe: Int; let chiusi: Int; let cartelle: Int; let irraggiungibili: Int }

/// Sidebar found in the previous pass (same Notes): no need to search for it again.
var barraInMemoria: (pid: pid_t, barra: AXUIElement)?

func trovaBarra(_ app: AXUIElement, _ pid: pid_t) -> AXUIElement? {
	if let m = barraInMemoria, m.pid == pid { return m.barra }
	guard let b = trovaBarraVeloce(app) ?? trovaBarraCompleta(app) else { return nil }
	barraInMemoria = (pid, b)
	return b
}

func comprimi(_ pid: pid_t) -> Esito? {
	let app = AXUIElementCreateApplication(pid)
	AXUIElementSetMessagingTimeout(app, 1.0)
	guard var barra = trovaBarra(app, pid) else { return nil }
	var lette = attributo(barra, kAXRowsAttribute) as? [AXUIElement]
	if lette == nil { // the remembered sidebar no longer exists: search again
		barraInMemoria = nil
		guard let b = trovaBarra(app, pid) else { return nil }
		barra = b
		lette = attributo(barra, kAXRowsAttribute) as? [AXUIElement]
	}
	guard let tutte = lette else { return nil }

	// one question per row: level, open/closed and its cell (for the arrow)
	let stati = tutte.map { r -> (livello: Int, aperta: Bool, celle: [AXUIElement]) in
		let v = attributi(r, ["AXDisclosureLevel", "AXDisclosing", kAXChildrenAttribute])
		return ((v[0] as? Int) ?? -1, (v[1] as? Bool) ?? false, (v[2] as? [AXUIElement]) ?? [])
	}
	// accounts closed → open them (normally there are none)
	for st in stati where st.livello >= 0 && st.livello < livelloMinimo && !st.aperta {
		if let f = triangolo(st.celle) { misura.conta { _ = AXUIElementPerformAction(f, kAXPressAction as CFString) } }
	}
	// open folders and subfolders → collapse them. Notes remembers each subfolder's
	// state separately, so all of them get closed, not only the main ones.
	// All the presses are sent without waiting for Notes' animation, strictly
	// bottom to top: each folder is closed before the one that contains it and the rows
	// still to be pressed (all above) don't move. Rows without an arrow (off-screen)
	// are handled by the next pass.
	let cartelle = stati.filter { $0.livello >= livelloMinimo }.count
	let daChiudere = stati.filter { $0.livello >= livelloMinimo && $0.aperta }
	var premute = 0
	for st in daChiudere.reversed() {
		guard let freccia = triangolo(st.celle) else { continue }
		AXUIElementSetMessagingTimeout(freccia, 0.05) // send and move on, without waiting
		misura.conta { _ = AXUIElementPerformAction(freccia, kAXPressAction as CFString) }
		premute += 1
	}
	return Esito(righe: tutte.count, chiusi: premute, cartelle: cartelle, irraggiungibili: daChiudere.count - premute)
}

// MARK: - Events

final class Controllore: NSObject {
	var passaggi: [DispatchWorkItem] = []

	override init() {
		super.init()
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(avviata(_:)),
			name: NSWorkspace.didLaunchApplicationNotification, object: nil)
		let fidato = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
		scrivi("started (final version), permission: \(fidato)")
	}

	@objc func avviata(_ n: Notification) {
		guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
			app.bundleIdentifier == notesID else { return }
		guard eNoteAutentica(app.processIdentifier) else {
			scrivi("ignored: an app calls itself Notes but isn't signed by Apple")
			return
		}
		esegui(app.processIdentifier)
	}

	/// Tries right away and again over the next seconds. It stops only when the sidebar
	/// has been stable for a moment: at least 1.5 s since it was first seen and
	/// 0.3 s since the last press, with nothing left to close. This way, if Notes loads
	/// slowly (e.g. after a restart) and expands the folders late, the next pass
	/// collapses them again. After that it doesn't touch Notes until the next launch.
	func esegui(_ pid: pid_t) {
		passaggi.forEach { $0.cancel() }
		passaggi = []
		barraInMemoria = nil
		misura.azzera()
		var dettagli: [String] = []
		let inizio = Date()
		var totaleChiusi = 0
		var primaVista: Int? = nil
		var ultimaPressione = 0
		func ms() -> Int { Int(Date().timeIntervalSince(inizio) * 1000) }
		let ritardi = [0.05, 0.15, 0.3, 0.5, 0.75, 1.0, 1.4, 1.8, 2.3, 3.0, 4.0, 5.0, 6.5]
		for ritardo in ritardi {
			let ultimo = ritardo == ritardi.last
			var item: DispatchWorkItem!
			item = DispatchWorkItem { [weak self] in
				guard let self, !item.isCancelled else { return }
				let inizioPassaggio = ms()
				let domandePrima = misura.chiamate
				guard let esito = comprimi(pid) else { return }
				totaleChiusi += esito.chiusi
				guard esito.cartelle > 0 else { return } // sidebar not loaded yet
				if primaVista == nil { primaVista = inizioPassaggio }
				if esito.chiusi > 0 { ultimaPressione = ms() }
				dettagli.append("[\(inizioPassaggio)→\(ms()) ms: \(esito.righe) rows, \(esito.chiusi) pressed, \(misura.chiamate - domandePrima) questions]")
				let stabile = inizioPassaggio - (primaVista ?? inizioPassaggio) >= 1500 && inizioPassaggio - ultimaPressione >= 300
				let finito = esito.chiusi == 0 && esito.irraggiungibili == 0
				if (finito && stabile) || ultimo {
					let extra = esito.irraggiungibili > 0 ? ", \(esito.irraggiungibili) not reached" : ""
					scrivi("opened: collapsed \(totaleChiusi)\(extra); sidebar ready at \(primaVista ?? 0) ms, last press at \(ultimaPressione) ms, verified at \(ms()) ms; \(misura.riassunto)")
					scrivi("   passes: " + dettagli.joined(separator: " "))
					self.passaggi.forEach { $0.cancel() }
				}
			}
			passaggi.append(item)
			DispatchQueue.main.asyncAfter(deadline: .now() + ritardo, execute: item)
		}
	}
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controllore = Controllore()
app.run()
