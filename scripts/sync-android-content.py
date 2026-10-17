#!/usr/bin/env python3
"""Compile the iOS medication catalog into an Android/JVM parity fixture."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "SimpleGLP/Models/GLPModels.swift").read_text()
prefix = source.split("enum InjectionSite:")[0].replace("import SwiftData\n", "")
exporter = '''
let rows = GLPMedication.allCases.map { medication -> [String: Any] in
    ["name": medication.rawValue, "form": medication.form.rawValue,
     "doses": medication.standardDoseStepsMg, "wait": medication.defaultWaitMinutes,
     "custom": medication.isCustom]
}
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
'''
with tempfile.TemporaryDirectory(prefix="simpleglp-content-") as temporary:
    swift = Path(temporary) / "main.swift"
    executable = Path(temporary) / "export"
    swift.write_text(prefix + exporter)
    subprocess.run(["swiftc", str(swift), "-o", str(executable)], check=True)
    result = subprocess.run([str(executable)], check=True, capture_output=True)
    (root / "android/app/src/main/resources/ios-medications.json").write_bytes(result.stdout + b"\n")
print("Exported 11 iOS medication records to Android parity fixture.")
