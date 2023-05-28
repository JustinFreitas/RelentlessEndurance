:: Assumes running from RelentlessEndurance\build
mkdir out\RelentlessEndurance
copy ..\extension.xml out\RelentlessEndurance\
copy ..\readme.txt out\RelentlessEndurance\
copy ..\"Open Gaming License v1.0a.txt" out\RelentlessEndurance\
mkdir out\RelentlessEndurance\graphics\icons
copy ..\graphics\icons\relentlessendurance_icon.png out\RelentlessEndurance\graphics\icons\
copy ..\graphics\icons\white_relentlessendurance_icon.png out\RelentlessEndurance\graphics\icons\
mkdir out\RelentlessEndurance\campaign
copy ..\campaign\ct_host.xml out\RelentlessEndurance\campaign\
mkdir out\RelentlessEndurance\scripts
copy ..\scripts\relentlessendurance.lua out\RelentlessEndurance\scripts\
copy ..\scripts\ct_host_ct_entry.lua out\RelentlessEndurance\scripts\
cd out
CALL ..\zip-items RelentlessEndurance
rmdir /S /Q RelentlessEndurance\
copy RelentlessEndurance.zip RelentlessEndurance.ext
cd ..
explorer .\out
