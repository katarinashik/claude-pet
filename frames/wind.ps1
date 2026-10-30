# storyboard frames for the wind scene (wind of 35 km/h or more): each Shot is one frame
# Set-Wind blowing frame lean paper onFace inHand onLid
Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false; Set-Wind $true 0 0 'gone' $false $false $false; Shot 'w1'   # typing, gusts start
Set-Wind $true 1 0 'gone' $false $false $false; Set-Eyes 0 4 $true; Shot 'w2'                                # stronger: leaves, ears flap, he squints
Set-Wind $true 0 0 'held' $false $false $false; Set-Happy $true; Set-Heart $true; Shot 'w3'               # he smells a rose...
Set-Heart $false; Set-Happy $false; Set-Wind $true 1 0 'snatch' $false $false $false; Set-Eyes -1 2 $false; $bang.Visibility = 'Visible'; Shot 'w4'   # ...a gust snatches it, he grabs after it!
$bang.Visibility = 'Hidden'; Set-Wind $true 0 0 'away' $false $false $false; Set-Eyes -1 2 $false; Shot 'w5'   # too late, it tumbles away, petals trailing
Set-Wind $true 1 0 'gone' $false $false $false; $askMark | ForEach-Object { $_.Visibility = 'Visible' }; Set-Eyes -1 3 $false; Shot 'w6'   # gone. "?"
$askMark | ForEach-Object { $_.Visibility = 'Hidden' }; Set-Wind $true 0 0 'gone' $true $false $false; Set-Eyes 0 4 $true; Shot 'w7'   # and a leaf slaps onto his face
Set-Wind $true 1 0 'gone' $false $true $false; Set-Eyes 0 3 $false; Shot 'w8'                                # peels it off, holds it up
Set-Wind $true 0 -1 'gone' $false $false $false; Set-Eyes 0 4 $true; Shot 'w9'                              # leans into the wind and types on
# the wind drops
Set-Wind $false 0 0 'gone' $false $false $true; Set-Eyes -1 4 $false; Shot 'w10'                            # calm; the last leaf lands on the lid
Set-Wind $false 0 0 'gone' $false $false $false; $bob.X = 0; Set-Happy $true; Shot 'w11'                    # flicks it away
Set-Happy $false; Set-Eyes 0 4 $false; Shot 'w12'                                                            # back to work
