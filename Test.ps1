Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- HIGH-RES CONFIG ---
$scrW = 1280; $scrH = 720; $res = 200 
$mWidth = 21; $mHeight = 21
$map = New-Object 'char[,]' $mWidth, $mHeight
for($y=0; $y -lt $mHeight; $y++){for($x=0; $x -lt $mWidth; $x++){$map[$x,$y]='#'}}

# --- GUARANTEED PATH ---
$cx=1;$cy=1
while($cx -lt 19 -or $cy -lt 19){
    $map[$cx,$cy]='.'
    if($cx -lt 19 -and (Get-Random 2) -eq 0){$cx++}elseif($cy -lt 19){$cy++}else{$cx++}
}
$map[19,19] = 'S'
for($i=0;$i -lt 150;$i++){
    $rx=Get-Random -Min 1 -Max 20; $ry=Get-Random -Min 1 -Max 20
    if($map[$rx,$ry]-eq '#'){$map[$rx,$ry]='.'}
}

# --- STATE ---
$px=1.5; $py=1.5; $pa=0.0; $fov=[Math]::PI/2.5; $bob=0.0; $flash=0
$music = Start-Job { while($true){ @(130,110,147)|%{[Console]::Beep($_,180)}; Start-Sleep -m 250 }}

$form = New-Object Windows.Forms.Form
$form.Text = "PowerDoom Ultra: Fixed Graphics"; $form.Size = "$scrW,$scrH"
$form.BackColor = "Black"; $form.StartPosition = "CenterScreen"
$type = $form.GetType(); $prop = $type.GetProperty("DoubleBuffered", 36); $prop.SetValue($form, $true, $null)

$form.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $w = [int]$form.ClientSize.Width; $h = [int]$form.ClientSize.Height
    $halfH = [int]($h / 2); $colW = $w / $res

    # 1. Background Slices
    for ($i=0; $i -lt 8; $i++) {
        $sliceH = [int]($halfH / 8); $yPos = $i * $sliceH
        $skyLum = [int](10 + ($i * 4)); $flrLum = [int](50 - ($i * 4))
        $g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(0, 0, $skyLum))), 0, $yPos, $w, $sliceH + 1)
        $g.FillRectangle((New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb($flrLum, $flrLum/2, 0))), 0, $h - $yPos - $sliceH, $w, $sliceH + 1)
    }

    # 2. 3D Raycasting
    for($x=0; $x -lt $res; $x++) {
        $rayA = ($pa - $fov/2) + ($x/$res)*$fov
        $dist = 0.0; $hit = $false; $vx = [Math]::Cos($rayA); $vy = [Math]::Sin($rayA)
        while(-not $hit -and $dist -lt 18){ 
            $dist += 0.05
            $tx=[int]($px+$vx*$dist); $ty=[int]($py+$vy*$dist)
            if($tx -ge 0 -and $tx -lt $mWidth -and $ty -ge 0 -and $ty -lt $mHeight){
                if($map[$tx,$ty]-ne '.'){$hit=$true}
            } else { $hit=$true }
        }
        $lineH = [int]($h / ($dist * [Math]::Cos($rayA - $pa)))
        $yOff = [int]([Math]::Sin($bob)*12)
        $bright = [Math]::Max(0, [int](240 - ($dist * 12)))
        $tx=[int]($px+$vx*$dist); $ty=[int]($py+$vy*$dist)
        $color = if($map[$tx,$ty]-eq 'S'){ [Drawing.Color]::Lime } else { [Drawing.Color]::FromArgb($bright, $bright, $bright) }
        $g.FillRectangle((New-Object Drawing.SolidBrush($color)), [int]($x * $colW), [int](($h - $lineH) / 2 + $yOff), [int]($colW + 1), $lineH)
    }

    # 3. FIXED WEAPON (No math in array)
    $gunX = [int]($w/2 - 100); $gunY = [int]($h - 180 + ([Math]::Abs([Math]::Sin($bob))*15))
    $p1 = New-Object Drawing.Point($gunX, $h)
    $p2 = New-Object Drawing.Point([int]($gunX + 40), $gunY)
    $p3 = New-Object Drawing.Point([int]($gunX + 160), $gunY)
    $p4 = New-Object Drawing.Point([int]($gunX + 200), $h)
    $g.FillPolygon([Drawing.Brushes]::DimGray, @($p1, $p2, $p3, $p4))
    if($script:flash -gt 0) { $g.FillEllipse([Drawing.Brushes]::Yellow, [int]($w/2 - 25), [int]($gunY - 30), 50, 50); $script:flash-- }

    # 4. MINIMAP RESTORED
    $ms = 8
    $g.FillRectangle([Drawing.Brushes]::Black, 15, 15, $mWidth*$ms+10, $mHeight*$ms+10)
    for($my=0;$my -lt $mHeight;$my++){ for($mx=0;$mx -lt $mWidth;$mx++){
        $color = if($map[$mx,$my] -eq '#'){[Drawing.Brushes]::Gray}elseif($map[$mx,$my] -eq 'S'){[Drawing.Brushes]::Lime}else{continue}
        $g.FillRectangle($color, [int]($mx*$ms+20), [int]($my*$ms+20), $ms-1, $ms-1)
    }}
    $g.FillEllipse([Drawing.Brushes]::Red, [int]($px*$ms+20), [int]($py*$ms+20), 5, 5)
})

$form.Add_KeyDown({
    $k = $_.KeyCode; $nx=$px; $ny=$py; $speed = if($_.Shift){0.4}else{0.2}
    if($k -eq "W"){$nx+=[Math]::Cos($pa)*$speed; $ny+=[Math]::Sin($pa)*$speed; $script:bob += 0.4}
    if($k -eq "S"){$nx-=[Math]::Cos($pa)*$speed; $ny-=[Math]::Sin($pa)*$speed; $script:bob += 0.4}
    if($k -eq "A"){$script:pa -= 0.15}
    if($k -eq "D"){$script:pa += 0.15}
    if($k -eq "Space"){$script:flash = 3; [Console]::Beep(110, 40)}
    if($map[[int]$nx,[int]$ny]-ne '#'){
        if($map[[int]$nx,[int]$ny]-eq 'S'){ Stop-Job $music; [Windows.Forms.MessageBox]::Show("MISSION SUCCESS"); $form.Close() }
        $script:px=$nx; $script:py=$ny
    }
    $form.Invalidate()
})

$form.Add_FormClosing({ Stop-Job $music })
[Windows.Forms.Application]::Run($form)
