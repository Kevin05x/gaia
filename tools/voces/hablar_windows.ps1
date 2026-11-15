# Sintetiza un texto con una voz de Windows (incluidas las OneCore, como Microsoft Pablo o Raúl) y lo guarda en WAV.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File hablar_windows.ps1 -Voz Pablo -Texto "Hola" -Salida C:\ruta.wav
# Sale con código 2 si la voz no está instalada en este equipo. Lo usa tools/voces/generar_voces.py (plan de mejoras 9.2).
param([string]$Voz, [string]$Texto, [string]$Salida)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]

function Esperar($operacion, [Type]$tipo) {
	$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
		$_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1"
	})[0]
	$tarea = $asTask.MakeGenericMethod($tipo).Invoke($null, @($operacion))
	$tarea.Wait(-1) | Out-Null
	return $tarea.Result
}

$voces = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.DisplayName -like "*$Voz*" }
if (-not $voces) { exit 2 }
$sintetizador = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$sintetizador.Voice = @($voces)[0]
$flujo = Esperar ($sintetizador.SynthesizeTextToStreamAsync($Texto)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
$lector = New-Object Windows.Storage.Streams.DataReader($flujo.GetInputStreamAt(0))
$tam = [uint32]$flujo.Size
Esperar ($lector.LoadAsync($tam)) ([uint32]) | Out-Null
$bytes = New-Object byte[] $tam
$lector.ReadBytes($bytes)
[IO.File]::WriteAllBytes($Salida, $bytes)
