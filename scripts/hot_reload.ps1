$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync('ws://127.0.0.1:58024/XPspmux38WM=/ws').Wait()
$msg = [System.Text.Encoding]::UTF8.GetBytes('{"jsonrpc":"2.0","id":"1","method":"HotReload"}')
$stream = [System.IO.MemoryStream]::new($msg)
$sendTask = $ws.SendAsync($stream, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
$sendTask.Wait()
$buf = New-Object byte[] 4096
$receiveTask = $ws.ReceiveAsync($buf, [System.Threading.CancellationToken]::None)
$receiveTask.Wait()
$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, $null, [System.Threading.CancellationToken]::None).Wait()
$ws.Dispose()
Write-Host "Hot reload sent"
