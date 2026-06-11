# Vision-to-MuseScore MCP Prototype

This is an isolated side project for testing whether a vision model can read one
measure from an original PDF and direct MuseScore through `mcp-musescore`.

It is not part of the AZMusic production server/client workflow. The V1 student
artifact remains the cleaned PDF.

## Goal

For the first pass, process one selected measure:

1. Crop one measure from a PDF page into a PNG.
2. Ask a local LM Studio vision model for structured measure facts.
3. Validate and save those facts as JSON.
4. Convert facts into a bounded MuseScore MCP command sequence.
5. Apply that sequence to a blank score in an interactive MuseScore session.

## External Dependency

Install and run `mcp-musescore` separately:

https://github.com/ghchen99/mcp-musescore

Expected interactive run shape:

1. Install `musescore-mcp-websocket.qml` in the MuseScore plugins folder.
2. Enable the plugin in MuseScore.
3. Open MuseScore with a blank score.
4. Start the plugin from `Plugins -> MuseScore API Server`.
5. Start the Python MCP server from the `mcp-musescore` checkout.

The upstream plugin runs a WebSocket server on port `8765`; the Python MCP
server exposes tools such as `ping_musescore`, `set_time_signature`,
`add_note`, `add_rest`, and `processSequence`.

## Setup

From the AZMusic repo root:

```powershell
Copy-Item experiments\musescore_mcp_vision\config.example.json `
  experiments\musescore_mcp_vision\config.local.json
```

Edit `config.local.json`:

- `input.pdf_path`: source PDF.
- `input.page_number`: 1-based page number.
- `input.measure_region`: normalized crop box for the target measure.
- `lm_studio.base_url`: LM Studio OpenAI-compatible URL.
- `mcp.server_command`: command that starts the `mcp-musescore` Python server.

On this development machine the dependency is installed at `C:\Tools\mcp-musescore`,
so the local command shape is:

```json
[
  "C:/Projects/AZMusic/server/.venv/Scripts/python.exe",
  "C:/Tools/mcp-musescore/server.py"
]
```

`measure_region` uses normalized page coordinates:

```json
{"x": 0.10, "y": 0.22, "width": 0.72, "height": 0.10, "units": "normalized"}
```

## Run

Extract the measure image:

```powershell
.\server\.venv\Scripts\python.exe -m experiments.musescore_mcp_vision.scripts.extract_measure_image `
  --config experiments\musescore_mcp_vision\config.local.json
```

Ask LM Studio for measure facts:

```powershell
.\server\.venv\Scripts\python.exe -m experiments.musescore_mcp_vision.scripts.analyze_measure_with_vision `
  --config experiments\musescore_mcp_vision\config.local.json
```

Dry-run the MuseScore command sequence:

```powershell
.\server\.venv\Scripts\python.exe -m experiments.musescore_mcp_vision.scripts.apply_measure_with_mcp `
  --config experiments\musescore_mcp_vision\config.local.json --dry-run
```

Apply to MuseScore through MCP:

```powershell
.\server\.venv\Scripts\python.exe -m experiments.musescore_mcp_vision.scripts.apply_measure_with_mcp `
  --config experiments\musescore_mcp_vision\config.local.json
```

Or run the full loop:

```powershell
.\server\.venv\Scripts\python.exe -m experiments.musescore_mcp_vision.scripts.run_one_measure_loop `
  --config experiments\musescore_mcp_vision\config.local.json
```

## Safety Rules

- The vision model must write schema-valid JSON before any MCP command runs.
- The MCP step writes only one measure.
- Low-confidence or structurally incomplete facts stop the run.
- Fingering and unsupported notation are preserved in JSON and reported as
  unsupported if the current MCP tool surface cannot apply them semantically.

## Output

By default, files are written under:

```text
experiments/musescore_mcp_vision/runs/latest/
```

Important outputs:

- `measure.png`: cropped original measure.
- `lm_studio_raw_response.json`: raw model response.
- `measure_facts.json`: validated structured facts.
- `musescore_sequence.json`: MCP command sequence.
- `mcp_result.json`: MCP call result when not using `--dry-run`.

## Current Local Probe

The current `config.local.json` targets page 47 of `Position Pieces for Cello,
Book 1.pdf` and uses the reachable LM Studio endpoint at
`http://192.168.1.93:1235/v1`.

The first probe successfully produced schema-valid measure facts, but the
sequence builder rejected them because the reported durations did not add up to
the visible `6/8` time signature. That rejection is intentional: the experiment
must not send unsafe notation to MuseScore.
