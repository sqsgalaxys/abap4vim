if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif


"---------------------------------------------
" Abapchdir
"
" Go to the ABAP path
" -------------------------------------------

function! Abapdir()

python << EOF
# -*- coding: UTF-8 -*-
import os, vim

home = os.environ['HOME']

vim.command("e "+home+"/abaped/")

EOF

endfunction

"---------------------------------------------
" Abapconf
" 
" Configure SAP Server
"---------------------------------------------
function! Abapconf()

split ~/abaped/server.cfg

endfunction


function! Abapconn()

python << EOF
# -*- coding: UTF-8 -*-

import os, vim
import easysap

home = '~'
if 'HOME' in os.environ:
    home = os.environ['HOME']


fin = open(home+"/abaped/server.cfg", 'r').read()
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
" Abapget , asks for the program name 
"
" Download ABAP Source code from SAP Server
"---------------------------------------------
function! Abapget()
    chdir ~
    if exists("g:pre")
        let g:arg = g:pre_prog
        g:pre = 0
    else
        let g:arg = input('ABAP program name: ')
    endif

    let g:conn = Abapconn()
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

    if 'HOME' in os.environ:
        home = os.environ['HOME']

        if not os.path.exists(home+"/abaped"):
            os.mkdir(home+"/abaped")
            print 'Created abaped path, please configure your SAP Connection...'

            defconf = """
SERVER =    # IP Address or hostname
SYSNR  =    # System Number
MANDT  =    # Client/Mandant
USER   =    # Default user
PASSWD =    # Password
            """

            open(home+"/abaped/server.cfg", 'w').write(defconf)

            vim.command("e! "+home + "/abaped/server.cfg")

        else:
            conn = vim.eval("g:conn")            
            sap  = easysap.SAPInstance()
            sap.set_config(conn)
            code = sap.download_abap(program)
            
            if len(code) > 0:
                if not os.path.exists(home + "/abaped/"+program):
                    os.mkdir(home+"/abaped/"+program)
                dw = home + "/abaped/"+program + "/"+ program  + ".abap" 
                
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
                        dw = home + "/abaped/"+program+"/" + inc_name + ".abap"
                        fo = open(dw, 'w')
                        fo.write(code)
                        fo.close()
                        vim.command('echom "Downloaded include '+ inc_name + '"')
                        includes = True
                dw = home + "/abaped/" + program + "/" + program + ".abap" 
                vim.command("e " + dw )
                if includes:
                    vim.command("vsplit " + home + "/abaped/"+program )
            else:
                print 'Source code not found!'
    else:
        print 'HOME path not found!'

    
except Exception, e:
    print e
    
EOF

endfunction


function! Abapreload()
let g:current_program = expand("%:t")

python << EOF
# -*- coding: UTF-8 -*-
import vim

program = vim.eval("g:current_program")
program, extension = program.split('.')
program = program.strip()

if extension == 'abap':
    if program[0].lower() not in 'xyz':
        print 'Standard program'
    else:
        vim.command("let g:pre = 1")
        vim.command("let g:pre_prog = '"+program+"'")
EOF

if g:pre_prog 
    if exists("g:pre")
        Abapget()
    endif
endif
endfunction


"-------------------------------------------
" AbapRun
" Run current buffer as ABAP program 
"------------------------------------------

function! Abaprun()
let g:full_path = expand("%:p")

let g:conn = Abapconn()

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
" AbapCommit
"
" Upload ABAP Code to SAP Server
"-------------------------------------------
function! Abapcommit()
let g:sc = Abapsyntax()
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
let g:conn      = Abapconn()
python << EOF
# -*- coding: UTF-8 -*-
import vim, os, easysap

program = vim.eval("g:current_program")
full_path = vim.eval("g:full_path")

if program.find('.') > 0:
    program, extension = program.split('.')
    if extension == 'abap':
        sap = easysap.SAPInstance()
        home = os.environ['HOME']
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

function! Abapsyntax()
let g:current_program = expand("%t")
let g:full_path = expand("%:p")
let g:conn = Abapconn()
let g:result = ''
python << EOF
# -*- coding: UTF-8 -*-
import vim, os, easysap

program = vim.eval("g:current_program")
full_path = vim.eval("g:full_path")

if program.find('.') > 0:
    program, extension = program.split('.')
    if extension == 'abap':
        if program.strip()[0].lower() not in 'xyz':
            print 'This seems a standart ABAP Code!:' + program
        else:
            sap = easysap.SAPInstance()
            home = os.environ['HOME']
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
function! TransportOrder()
    let g:object = input('Object: ')
    let g:conn = Abapconn()

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
           WHERE a~obj_name = '%s'
             AND c~trfunction = 'K'.

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
function! TransportOrderObjects()
    let g:torder = input('Transport Order: ')
    let g:conn   = Abapconn()

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
            obj_name like e071-obj_name,
        END OF wa_objects,

        it_objects like wa_objects occurs 0.


    SELECT obj_name FROM e071 
    INTO TABLE it_objects 
    WHERE TRKORR = '%s'
      AND OBJECT <> 'RELE'.

    LOOP AT it_objects 
        INTO wa_objects.
        WRITE:/ wa_objects-obj_name.
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
