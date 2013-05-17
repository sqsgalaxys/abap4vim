if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif


let g:mainpath = 'ABAP4Vim'
let g:homepath = '~'


"---------------------------------------------
" Go to the main path
" -------------------------------------------
function! A4V_dir()

    let g:home = A4V_home_path()

python << EOF
# -*- coding: UTF-8 -*-
import os, vim

path = vim.eval('g:mainpath')

home = vim.eval('g:home')

vim.command("e "+home+"/"+path+"/")

EOF

endfunction

"---------------------------------------------
" Configure SAP Server
"---------------------------------------------
function! A4V_conf()

split ~/ABAP4Vim/server.cfg

endfunction


"------------------------------
" Check initial installation
"------------------------------
function! A4V_init()
    let g:result = ''

python << EOF 
if 'HOME' in os.environ:
    home = os.environ['HOME']
    home = home.replace('\\', '/')
    path = vim.eval("g:mainpath")

    if not os.path.exists(home+"/"+path):
        os.mkdir(home+"/"+path)
        os.mkdir(home+"/"+path+"/programs")
        os.mkdir(home+"/"+path+"/function_modules")
        vim.eval('input("Configuring ABAP4Vim, please configure your SAP Connection...")')

        defconf = """
SERVER =    # IP Address or hostname
SYSNR  =    # System Number
MANDT  =    # Client/Mandant
USER   =    # Default user
PASSWD =    # Password
            """

        open(home+"/"+path+"/"+"server.cfg", 'w').write(defconf)
        vim.command("e! "+home + "/"+path+"/"+"server.cfg")
    else:
        vim.command('let g:result = "X"')
else:
    print 'HOME path not found!'

EOF 
    return g:result

endfunction

"------------------------------
" Generate default directories
"------------------------------


"------------------------------
" Generate configuration file
"------------------------------
function! A4V_gen_cfgfile()

endfunction


"---------------------------
" Get Home Path 
"---------------------------
function! A4V_home_path()

    let g:home = ''
python << EOF 
import os, vim

if 'HOME' in os.environ:
    home = os.environ['HOME']
    home = home.replace('\\', '/')
else:
    home = '~'

vim.command("let g:home = '"+home+"'")

EOF 
    return g:home

endfunction

"-----------+---------------
" Get SAP Connection String
"---------------------------
function! A4V_conn()

let g:home = A4V_home_path()

python << EOF
# -*- coding: UTF-8 -*-

import os, vim
import easysap

path = vim.eval('g:mainpath')
home = vim.eval('g:home')


cfg = home+"/"+path+"/"+"server.cfg"

conn = ''

if not os.path.exists(cfg):
    vim.eval("A4V_gen_cfgfile()")

fin = open(cfg, 'r').read()
VARS = { 'SERVER': '', 
            'SYSNR': '',
            'MANDT': '',
            'USER': '',
            'PASSWD': ''
            }
fin = fin.split('\n')

for line in fin:
    line = line.strip()
    if len(line) == 0:
        continue
    if line.find("#") > 0:
        pair, comments = line.split("#")
        var, value = pair.split("=")
        var = var.upper()
        var = var.strip()
        value = value.strip()

        if var in VARS.keys():
            VARS[var] = value
conn = easysap.getConnString(VARS['SERVER'], VARS['SYSNR'], VARS['MANDT'], VARS['USER'], VARS['PASSWD'])
         


vim.command('let g:conn = "' + conn + '"')

EOF

return g:conn

endfunction

"---------------------------------------------
" Download ABAP Source code from SAP Server
"---------------------------------------------
function! A4V_get_program()
    chdir ~
    if exists("g:pre")
        let g:arg = g:pre_prog
        g:pre = 0
    else
        let g:cfgred = A4V_init()
        if g:cfgred ==? 'X'
            let g:arg = input('Program name: ')
        else 
            return
        endif
    endif
    let g:conn = A4V_conn()
    let g:home = A4V_home_path()
python << EOF
# -*- coding: UTF-8 -*-

import os, vim

try:
    import easysap
except Exception, e:
    print 'Easysap library required'

# ABAP programs will be stored in the following path
try:
    program = vim.eval("g:arg") 

    if program != None:
        path = vim.eval('g:mainpath')
        conn = vim.eval('g:conn')            
        home = vim.eval("g:home")

        sap  = easysap.SAPInstance()
        sap.set_config(conn)
        code = sap.download_abap(program)

        path = home + "/"+path+"/programs/"+program

        if len(code) > 0:
            if not os.path.exists(path):
                os.mkdir(path)
            dw = path + "/"+ program  + ".abap" 
            
            fo = open(dw, 'w')
            fo.write(code)
            fo.close()
            
            # look for include programs
            code = code.split('\n')
            includes = False
            for line in code:
                inc_name = ''
                if line.upper().find('INCLUDE') >= 0:
                    words = line.split(' ')
                    next = False
                    for word in words:
                        if next:
                            inc_name = word.strip()
                            inc_name = inc_name.replace('.', '')
                            if inc_name.upper() == 'STRUCTURE':
                                inc_name = ''
                            break
                        if word.upper().strip() == 'INCLUDE':
                            next = True
                if len(inc_name) > 0:
                    code = sap.download_abap(inc_name)
                    dw = path + "/" + inc_name + ".abap"
                    fo = open(dw, 'w')
                    fo.write(code)
                    fo.close()
                    vim.command('echom "Downloaded include '+ inc_name + '"')
                    includes = True
            dw = path + "/" + program + ".abap" 
            vim.command("e " + dw )
            if includes:
                vim.command("vsplit " + path)
        else:
            print 'Source code not found!'
    else:
        print 'Operation cancelled!'

    
except Exception, e:
    print 'ERROR: ', e
    
EOF

endfunction

"--------------------------------------------
" Download Function Module Code 
"--------------------------------------------
function! A4V_get_function()
chdir ~
let g:cfgred = A4V_init()
if g:cfgred ==? 'X'
    let g:arg = input('Function Module name: ')
else
    return
endif

let g:conn = A4V_conn()
let g:home = A4V_home_path()

python << EOF 
import vim
import easysap

path = vim.eval('g:mainpath')
home = vim.eval('g:home')

function = vim.eval("g:arg")

conn = vim.eval("g:conn")

sap = easysap.SAPInstance()
sap.set_config(conn)
info, code = sap.download_fm(function)

if code != None and len(code) > 0:
    funpath = home + '/' + path + "/function_modules/" + function 
    if not os.path.exists(funpath):
        os.mkdir(funpath)

    dw = funpath + "/" + function + '.abap'
    fo = open(dw, 'w')
    fo.write(code)
    fo.close()

    di = funpath + "/" + function + '.info'
    fo = open(di, 'w')
    fo.write(str(info))
    fo.close()

    vim.command("e " + dw)
else:
    print 'Source code not found!'

EOF 

endfunction

"-------------------------------------------
" Download function module minidocumentation
"-------------------------------------------
function! A4V_fm_info()
let g:fname = input("Function Module Name: ")
let g:conn  = A4V_conn()

python << EOF 
import vim, easysap 

funct = vim.eval("g:fname")
conn  = vim.eval("g:conn")

if funct != None:
    sap = easysap.SAPInstance()
    sap.set_config(conn)

    info = sap.download_fm_info(funct)

    minidoc = ''
    vim.command('vsplit')
    vim.command('enew')
    for key in info.keys():
        new_key = {'I': 'Imports',
                   'E': 'Exports',
                   'T': 'Tables'}

        vim.current.buffer.append(new_key[key] + ':')
        vim.current.buffer.append('')
        for param in info[key]:
            vim.current.buffer.append('\t' + param['NAME'])
            vim.current.buffer.append('')
EOF 
endfunction


function! A4V_fm_pattern()
    let line=getline('.')
    echo line
endfunction



"-------------------------------------------
" Reload current program 
"-------------------------------------------
function! A4V_reload()
let g:current_program = expand("%:t")

python << EOF
# -*- coding: UTF-8 -*-
import vim

program = vim.eval("g:current_program")
program, extension = program.split('.')
program = program.strip()

if extension.upper() == 'ABAP':
    if program[0].lower() not in 'xyz':
        print 'Standard program'
    else:
        vim.command("let g:pre = 1")
        vim.command("let g:pre_prog = '"+program+"'")
EOF

if g:pre_prog 
    if exists("g:pre")
        A4V_get()
    endif
endif
endfunction


"-------------------------------------------
" Run current buffer as ABAP program 
"------------------------------------------

function! A4V_run()
let g:full_path = expand("%:p")

let g:conn = A4V_conn()

python << EOF
import vim, easysap, os

full_path = vim.eval("g:full_path")

sap = easysap.SAPInstance()

conn = vim.eval("g:conn")

sap.set_config(conn)

code = open(full_path, 'r').read()
code = str(code)

result = sap.executeABAP(code)


for line in result:
    print line

EOF

endfunction

"-------------------------------------------
" Upload ABAP Code to SAP Server
"-------------------------------------------
function! A4V_commit()
let g:sc = A4V_syntax()
let g:cont = "K"

if g:sc ==? "OK"
    let g:cont = "J"
    echom "Syntax OK"
else
    echo g:sc
    let g:cont = input("There are some syntax problems, do you want to continue?(j=Yes k=No) ")
endif

if g:cont ==? "J"
    let g:cont = "J"
else
    return "" 
endif

let g:current_program = expand("%:t")
let g:full_path = expand("%:p")
let g:conn      = A4V_conn()
let g:home      = A4V_home_path()
python << EOF
# -*- coding: UTF-8 -*-
import vim, os, easysap, ast

program = vim.eval("g:current_program")
full_path = vim.eval("g:full_path")

fp = full_path.split('\\')
fp = fp[::-1]

error = False
if fp[2].lower() == 'function_modules':
    info = full_path[:-5] + '.info' 
    if os.path.exists(info):
        info = open(info, 'r').read()
        info = ast.literal_eval(info)
        program = info['INCLUDE'] + '.abap'
    else:
        error = True


if program.find('.') > 0 and not error:
    program, extension = program.split('.')
    if extension.upper() == 'ABAP':
        sap = easysap.SAPInstance()
        home =  vim.eval('g:home')
        conn = vim.eval("g:conn") 
        sap.set_config(conn)

        code = open(full_path, 'r').read()
        code = str(code)
        ok = sap.upload_abap(program, code)            

        if ok:
            print 'Code uploaded successfully!'
        else:
            print 'ERROR uploading ABAP Source code'
                

EOF

endfunction

function! A4V_syntax()
let g:current_program = expand("%t")
let g:full_path = expand("%:p")
let g:conn = A4V_conn()
let g:home = A4V_home_path()
let g:result = ''
python << EOF
# -*- coding: UTF-8 -*-
import vim, os, easysap

program = vim.eval("g:current_program")
full_path = vim.eval("g:full_path")

if program.find('.') > 0:
    program, extension = program.split('.')
    if extension.upper() == 'ABAP':
        if program.strip()[0].lower() not in 'xyz':
            print 'This seems a standart ABAP Code!:' + program
        else:
            sap = easysap.SAPInstance()
            home = vim.eval("g:home")
            conn = vim.eval("g:conn")
            sap.set_config(conn)

            code = open(full_path, 'r').read()
            code = str(code)

            result = sap.syntax_check(program, code)

            if len(result) > 0:
                if type(result) == type([]):
                    result = result[0]
            print result
            vim.command("let g:result = '"+str(result)+"'")

EOF
return g:result
endfunction 


"-------------------------------------------
" Get transport order containing an object "
"------------------------------------------"
function! A4V_TransportOrder()
    let g:object = input('Object: ')
    let g:conn = A4V_conn()

python << EOF
import vim, easysap 

obj = vim.eval("g:object")

if obj != None:
    obj = obj.upper()

    program ="""
    REPORT ZGET_TO.

    DATA:
        begin of wa_to,
            trkorr like e071-trkorr,
            as4user like e070-as4user,
            as4text like e07T-as4text,
        end of wa_to,

        it_to like wa_to occurs 0,
        
        v_result type string.

    SELECT a~trkorr 
           c~as4user
           b~as4text
           INTO TABLE it_to
           FROM e071 as a 
           INNER JOIN e07T as b 
           ON ( a~trkorr = b~trkorr )
           INNER JOIN e070 as c 
           ON ( c~trkorr = b~trkorr )
           WHERE a~obj_name = '%s'.

    LOOP AT it_to 
        INTO wa_to.

        concatenate 
            wa_to-trkorr
            wa_to-as4user
            wa_to-as4text 
            INTO v_result SEPARATED BY space.

        WRITE:/  v_result.
    ENDLOOP.

    """ % obj

    sap = easysap.SAPInstance() 
    conn = vim.eval("g:conn")

    sap.set_config(conn)

    result = sap.executeABAP(program)

    total = len(result)

    vim.current.buffer.append('-'*80)
    vim.current.buffer.append('- Transport Orders: ' + str(total))
    vim.current.buffer.append('='*80)

    for line in result:
        line = line.split(' ')
        trkorr = line[0]
        user   = line[1]
        descr  = ' '.join(line[2:])

        line = trkorr +'\t' + user + '\t' + descr 

        vim.current.buffer.append(line)

EOF

endfunction

"--------------------------------------------"
" Objects in transport order 
"--------------------------------------------!
function! A4V_TransportOrderObjects()
    let g:torder = input('Transport Order: ')
    let g:conn   = A4V_conn()

python << EOF 
import vim, easysap

torder = vim.eval("g:torder")

if torder != None:
    torder = torder.upper()
    torder = torder.strip()

    program = """
    REPORT ZTO.

    DATA:
        BEGIN OF wa_objects,
            objext   like e071-object,
            obj_name like e071-obj_name,
        END OF wa_objects,

        it_objects like wa_objects occurs 0.


    SELECT object, obj_name FROM e071 
    INTO TABLE it_objects 
    WHERE TRKORR = '%s'
      AND OBJECT <> 'RELE'.

    LOOP AT it_objects 
        INTO wa_objects.
        WRITE:/ '[', wa_objects-object, '] - ', wa_objects-obj_name.
    ENDLOOP.
    """ % torder

    sap = easysap.SAPInstance()
    conn = vim.eval("g:conn")

    sap.set_config(conn)

    result = sap.executeABAP(program)

    total = len(result)

    vim.current.buffer.append('-'*80)
    vim.current.buffer.append('- Objects in transport order: '+str(total))
    vim.current.buffer.append('='*80)

    for line in result:
        vim.current.buffer.append(line)

EOF 

endfunction


"-----------------------------------------------
" T100 Messages 
"-----------------------------------------------
function! A4V_T100()
    let g:fare = input('Functional area: ')
    let g:msgn = input('Message number: ')
    let g:lang = input('Language: ')
    let g:conn = A4V_conn()

python << EOF 
import vim, easysap 

fare = vim.eval('g:fare')
msgn = vim.eval('g:msgn')
lang = vim.eval('g:lang')

fare = fare.upper()
msgn = msgn.upper()
lang = lang.upper()


if len(lang) == 0:
    lang = 'E'

if fare != None and msgn != None: 
    fare = fare.upper()
    msgn = msgn.upper()

    program = """
REPORT ZMSGS.

TABLES: 
    T100.

SELECT SINGLE * 
FROM T100 
WHERE ARBGB = '%s'
  AND MSGNR = '%s'
  AND SPRSL = '%s'.

  WRITE:/ T100-TEXT.
    """ % (fare, msgn, lang)


    sap = easysap.SAPInstance()
    sap.set_config(vim.eval("g:conn"))

    result = sap.executeABAP(program)

    if len(result)> 0:
        print result[0]

EOF 

endfunction

"----------------------------------------
" Function Module Pattern
"----------------------------------------
function! FMPattern()
    let g:conn =  A4V_conn()
endfunction




