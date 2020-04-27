{ -= Waving Blocks Intro =-

 Code by Abaddon

}


Program Intro5;
uses crt,misc;

{$F+}
{$L AMDOBJ.OBJ}
PROCEDURE _AdlibPlayer; near; EXTERNAL;
PROCEDURE _StopAdlib; near; EXTERNAL;
PROCEDURE _InitAdlib; near; EXTERNAL;

{$F-}

{$L SONG.OBJ}
Procedure SONG; external;   {includes the songs}

const
     min     = 5;    {minimal block size}

     nummsg = 3;
     speed = 20;
     ty    = 54;


type
     Virtual = Array [1..65535] of byte;  { The size of our virtual Screen }
     VirtPtr = ^Virtual;                  { Pointer to the virtual screen }
     OneChar = array[1..8] of byte;       { Data for the 8x8 IBM-font}


     Block   = record                     {all data for one block in our field}
      size   : byte;
      pal    : byte;
      ud     : boolean;
     end;

const
  msg : array[1..3] of array[1..7] of string =

 (('****************************',
   '  Today we proudly preset   ',
   '    Prince of Persia 2:     ',
   ' The shadow and the flame   ',
   '    Brought to you by       ',
   '   - The Code Breaker -     ',
   '****************************'),

  ('****************************',
   '    DOC-Check removed by    ',
   '           Abbadon          ',
   '  Another oldschool crack   ',
   '    for a classic game.     ',
   '  Watch out for the next!   ',
   '****************************'),

  ('****************************',
   '       Intro-Credits:       ',
   '       --------------       ',
   '    Coding: Abaddon /AcId   ',
   '        Music: Spy          ',
   ' Player: Conqueror/Elyssis  ',
   '****************************')


   );

 scrolly : string
 = 
   'Today I disassembled POP2 and removed the annoying copy protection.'+ 
   'So have fun playing it without disruption. '+
   'Greetings fly out to Feanor''s Curse, Kitty, MP45, Ceasar and all I have '+
   'forgotten. See you on our next release. Bye for now';






var
 Virscr                 : VirtPtr;   {Virtual screen}
 BlockMap               : array[0..15]of array [0..9] of block;{Block data}
 Vaddr                  : word;      {The segment for the virtual screen}
 z                      : word;      {Just a counter}
 charset                : array[1..256] of onechar; {Code Page}                 {Die Codepage}
 xcnt,dx,dy             : word;
 msgcnt,dc,tz           : byte;
 textin                 : boolean;
 scrx                   : integer;

 buffer,songptr         : pointer;




Procedure PutPixel(x,y:word; c:byte);
{Puts a pixel}
assembler;
asm
  mov es,vaddr
  mov ax,[y]
  shl ax,6
  mov di,ax
  shl ax,2
  add di,ax
  add di,[x]
  mov al,[c]
  stosb
end;


Procedure Blank(segment : word);
{Clears one segment of memory}
assembler;
asm
   mov ax, segment
   mov es, ax
   mov di, $FFFF;
@Loop:
   xor al, al
   mov es:[di],al
   dec di
   jnz @Loop
   mov es:[di],al
end;


Procedure Vretrace;
{wait for complete vertical retrace }
assembler;
asm
  mov dx,3dah
 @vert1:
  in al,dx
  test al,8
  jz @vert1
 @vert2:
  in al,dx
  test al,8
  jnz @vert2
end;


Procedure Flip(source,dest:Word); assembler;
{copy the entire segment from "source" to "dest" }
asm
  push    ds
  mov     ax, [Dest]
  mov     es, ax
  mov     ax, [Source]
  mov     ds, ax
  xor     si, si
  xor     di, di
  mov     cx, 16000
  db      $F3, $66, $A5
  pop     ds
end;


Procedure Setrgb(index,R,G,B:Byte);
assembler;
{ Change the palette}
asm
  mov dx,3c8h
  mov al,[index]
  out dx,al
  inc dx
  mov al,[r]
  out dx,al
  mov al,[g]
  out dx,al
  mov al,[b]
  out dx,al
end;

Procedure Create_Virtual_Screen;
   { This sets up the memory needed for the virtual screen }
begin
  GetMem (VirScr,65535);
  vaddr := seg (virscr^);
  blank(vaddr);
end; {Setupvirtual}

Procedure Destroy_Virtual_Screen;
   { This frees the memory used by the virtual screen }
begin
  blank(vaddr);
  FreeMem (VirScr,65535);
  vaddr := 0;
end;  {Shutdown}


Procedure FillBox(xf,yf,size,pal : byte);
{Draws a filled block at xf,yf with size "size"
 pal defines the starting color}
var cx,cy,ox,ox1,oy,oy1 : word;
begin
 if size > 18 then size := 0;

if (size >= 1) then
begin


 ox :=  (xf*(320 div 16) + (10 - (size div 2)));
 ox1 := (xf*(320 div 16) + (10 + (size div 2)));
 oy :=  (yf*(200 div 10) + (10 - (size div 2)));
 oy1 := (yf*(200 div 10) + (10 + (size div 2)));


for cy := oy to oy1 do
begin
 for cx := ox to ox1 do
 begin
  if (cx < 320) and (cy < 200) then
  begin
   putpixel(cx,cy,pal+size);
  end;
 end;
end;
end;
end;


Procedure DrawField;
{Draws actual field data to the screenuffer}
var cx,cy    : byte;
begin
for cy := 1 to 8 do
begin
 for cx := 0 to 15 do
   FillBox(cx,cy,BlockMap[cx][cy].size,BlockMap[cx][cy].pal);
end;
end;


Procedure DoWave(min : byte);
{wave it!}
var cx,cy,pc,s : byte;

begin
for cy := 0 to 9 do
begin
 for cx := 0 to 15 do
 begin
  if BlockMap[cx][cy].ud then           {block is growing}
  begin
   if BlockMap[cx][cy].size < 18 then   {not full size? Continue grow}
   begin
    inc(BlockMap[cx][cy].size);
   end
   else
   begin
    BlockMap[cx][cy].ud := false;      {esle stop growing}
   end;
  end
  else                                 {block is shrinking}
  begin
   if BlockMap[cx][cy].size > min then   {larger than min?}
   begin
    dec(BlockMap[cx][cy].size);          {so shrink it}
   end
   else
   begin
    BlockMap[cx][cy].ud := true;        {minimum size reached? So grow again..}
   end;
  end;
 end;
end;
end;



Procedure InitWave;
{Set the inital values for a nice wave}
var cx,cy,c : byte;

begin
for cy := 0 to 9 do
begin
 for cx := 0 to 15 do
 begin
   BlockMap[cx][cy].size := cx+cy;
   if BlockMap[cx][cy].size > 18 then
   begin
    BlockMap[cx][cy].size := 18-(((cx+cy)-18));
   end;
 end;
end;
end;





Procedure Load_BIOS_font;
{Loads the font out of the ROM}
var
 memcounter,               {memmory counter}
 bytecounter,              {byte counter}
 charcounter : integer;    {character counter}
begin
 memcounter := 0;
  for charcounter := 1 to 256 do
  begin
    for byteCounter:= 1 to 8 do
    begin
     charset[charcounter][Bytecounter] := Mem[$0F000:$0FA6E+memcounter];
     inc(memcounter);
    end;
   end;
end;


Procedure Out(x,y,size,v : word; color : byte; text : string);
{draw a string in the IBM 8x8 font
v = versetzt :) }
  var
    MemPos,
    TempPos : word;
    Count,
    xp,yp,
    XC,YC   : integer;
    Letter  : OneChar;
    original : byte;


  begin
    original := color;
    for count := 1 to length(text) do {draw the sepcified number of chars}
    begin

     letter := Charset[ord(text[count])+1]; {witch char ?}
     temppos := 0;
     mempos := 1;

     for yc := 1 to 8 do                    {Y byte}
     begin
      for xc := 8 downto 1 do
      begin
       if (getbit(letter[mempos],temppos) = 1) then
       begin
        xp := x+(xc*size);
        yp := y+(yc*size);

        if v > 0 then
        begin
         if odd(yc-y) then
         begin
           xp := xp + v;
         end
         else
         begin
           xp := xp - v;
         end;
        end;

        if (xp < 320) and (xp > 0) and
           (yp < 200) and (yp > 0) then
        putpixel(xp,yp,color);
       end;
       inc(temppos);
      end;
       inc(color);
       inc(mempos);
       if mempos > 8 then mempos := 1;
       temppos := 0;
     end;

     color := original;
     inc(x,8*size);
    end;
  end;


  Procedure CopperLine(ly : byte);
  var lx : word;
      lc,c : byte;
  begin
   lx := 30;
   lc := 36;
   c := 1;
   repeat;
    Putpixel(lx,ly,lc);
    inc(c);
    if c = 3 then
    begin
     c := 1;
     if lc < 152 then inc(lc);
    end;

    inc(lx);
   until lx = 320;



 end;



begin



 asm
  mov ax,13h            {Set Mode 13h (320x200x256}
  int 10h
 end;

 Load_BIOS_Font;
 Create_Virtual_Screen; {Creates a screen buffer in mem}

 getmem(buffer,1314);
 songptr := @song;

   asm
   push   ds
   push   es
   les    di,Buffer
   lds    si,songptr
   xor    al,al           (* irqmode!! *)
   call   _InitAdlib
   pop    es
   pop    ds
  end;


 for z := 20 downto 1 do      {Create the color palette for the blocks}
 begin
  setrgb(z,z,z,z);
 end;

 for z := 0 to 63 do
 begin 
  setrgb(z+30,z,0,0);
  setrgb(152-z,z,0,0);
 end;


 while keypressed do readkey;  {Clear keyboard signals}

 InitWave;           {Init wave data}
 msgcnt := 1;
 dc := 1;
 dx := 320;
 textin := true;
 scrx := 360;
 repeat;
  DoWave(min);      {Calcualte the next move of the wave}
  DrawField;        {and draw it to buffer}



   if textin then
   begin

    for tz := 1 to dc do
    begin
     if tz = dc then
     begin
      out(160-((length(msg[msgcnt][tz])*8) div 2),ty+(tz*10),1,dx,21,msg[msgcnt][tz]);
     end
     else
     begin
      out(160-((length(msg[msgcnt][tz])*8) div 2),ty+(tz*10),1,0,21,msg[msgcnt][tz]);
     end;
    end;
    dec(dx,speed);
    if dx <= 0 then
    begin
     inc(dc);
     if dc = 8 then
     begin
      textin := false;
      dc := 1;
     end;
      dx := 320;
    end;

   end
   else
   begin


   for tz := dc to 7 do
   begin
    if tz = dc then
    begin
     out(160-((length(msg[msgcnt][tz])*8) div 2),ty+(tz*10),1,dx,21,msg[msgcnt][tz]);
    end
    else
    begin
     out(160-((length(msg[msgcnt][tz])*8) div 2),ty+(tz*10),1,0,21,msg[msgcnt][tz]);
    end;
   end;
    inc(dx,speed);

    if dx > 320 then
    begin
     inc(dc);
     dx := 0;
     if dc = 8 then
     begin
      dc := 1;
      dx := 320;
      textin := true;
      inc(msgcnt);
      if msgcnt = nummsg+1 then msgcnt := 1;
     end;
    end;

   end;


   Copperline(18);

   Copperline(182);

   out(scrx,183,2,0,21,scrolly);
   dec(scrx);
   if scrx < 0-(length(scrolly)*16) then scrx := 360;

  flip(vaddr,$0A000); {copy buffer to screen}
  blank(vaddr);     {clear buffer}
 until keypressed;

 Destroy_Virtual_Screen;         {Free memory}


asm
 mov ax,03h        {Return to textmode}
 int 10h
 call   _StopAdlib
end;
 freemem(buffer,1314);
 writeln('Coded by Abaddon/Code Breaker');
end.
