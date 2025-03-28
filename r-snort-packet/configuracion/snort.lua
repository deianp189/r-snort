---------------------------------------------------------------------------
-- Snort++ configuration
---------------------------------------------------------------------------

-- there are over 200 modules available to tune your policy.
-- many can be used with defaults w/o any explicit configuration.
-- use this conf as a template for your specific configuration.

-- 1. configure defaults
-- 2. configure inspection
-- 3. configure bindings
-- 4. configure performance
-- 5. configure detection
-- 6. configure filters
-- 7. configure outputs
-- 8. configure tweaks

---------------------------------------------------------------------------
-- 1. configure defaults
---------------------------------------------------------------------------

-- HOME_NET and EXTERNAL_NET must be set now
-- setup the network addresses you are protecting
HOME_NET = 'any'

-- set up the external network addresses.
-- (leave as "any" in most situations)
EXTERNAL_NET = 'any'

include 'snort_defaults.lua'

---------------------------------------------------------------------------
-- 2. configure inspection
---------------------------------------------------------------------------

-- mod = { } uses internal defaults
-- you can see them with snort --help-module mod

-- mod = default_mod uses external defaults
-- you can see them in snort_defaults.lua

-- the following are quite capable with defaults:

stream = { }
stream_ip = {
    max_frags = 8192,            -- máximo número de fragmentos simultáneos
    max_overlaps = 5,            -- máximo número permitido de solapamientos (0 para ilimitado)
    min_frag_length = 128,       -- alerta si la longitud del fragmento es menor que 128 bytes
    min_ttl = 5,                 -- ignora fragmentos con TTL menor a 5
    policy = 'linux',            -- política de reensamblado (por defecto recomendado)
    session_timeout = 60,        -- tiempo en segundos antes de eliminar una sesión de reensamblado IP
}

stream_icmp = { }
stream_tcp = {
    policy = 'linux',                       -- Política de reensamblado optimizada para Linux
    max_window = 1048576,                   -- Ventana TCP máxima permitida (1 MB, segura y suficiente para la mayoría de las PYMES)
    overlap_limit = 10,                     -- Limita la cantidad máxima de segmentos solapados (protege contra ataques de evasión)
    max_pdu = 16384,                        -- Tamaño máximo permitido para PDU reensambladas (16 KB, valor seguro por defecto)
    reassemble_async = true,                -- Reensamblar aunque el tráfico aún no se haya visto en ambas direcciones
    queue_limit = {
        max_bytes = 4194304,                -- Máximo de bytes en cola por sesión/dirección (4 MB, valor seguro estándar)
        max_segments = 2048,                -- Máximo número de segmentos en cola por sesión/dirección
        asymmetric_ids_flush_threshold = 2097152, -- Umbral de descarga para flujos asimétricos (2 MB, protege memoria)
    },
    small_segments = {
        count = 5,                          -- Genera alerta si se reciben 5 segmentos TCP pequeños consecutivos
        maximum_size = 64,                  -- Considera pequeño cualquier segmento menor a 64 bytes
    },
    session_timeout = 180,                  -- Tiempo de espera para cerrar sesiones inactivas (3 minutos)
    embryonic_timeout = 30,                 -- Tiempo de espera para conexiones no establecidas (30 segundos)
    idle_timeout = 1800,                    -- Cerrar sesiones tras 30 min sin actividad (libera recursos)
}

stream_udp = { }
stream_user = { }
stream_file = { }

arp_spoof = { }
back_orifice = { }
dns = { }
imap = { }
netflow = {}
normalizer = { }
pop = { }
rpc_decode = { }
sip = { }
ssh = { }

ssl = {
    -- Por defecto, no se confía en servidores externos automáticamente
    trust_servers = false,

    -- Establece un límite para evitar ataques tipo Heartbleed
    max_heartbeat_length = 2048,
}

telnet = { }

cip = { }
dnp3 = { }
iec104 = { }
mms = { }
modbus = { }
s7commplus = { }

dce_smb = { }
dce_tcp = { }
dce_udp = { }
dce_http_proxy = { }
dce_http_server = { }

-- see snort_defaults.lua for default_*
gtp_inspect = default_gtp
port_scan = default_med_port_scan
smtp = default_smtp

ftp_server = default_ftp_server
ftp_client = { }
ftp_data = { }

-- http_inspect para inspección HTTP
http_inspect = 
{
    -- Escanear todo el cuerpo de la petición/respuesta (ojo a la carga en una Pi)
    request_depth = -1,
    response_depth = -1,
    
    -- Activa descompresión de gzip/deflate para inspeccionar payload
    unzip = true,
    
    -- Longitud máxima de directorio en URI, pasado este valor se dispara alerta 119:15
    oversize_dir_length = 500,
    
    -- Número máximo de cabeceras permitidas (ej. 200), si se superan -> alerta 119:20
    maximum_headers = 200,
    
    -- Tamaño máximo (en bytes) de una cabecera individual antes de alertar 119:19
    maximum_header_length = 4096,
    
    -- ¿Normalizar caracteres UTF en las respuestas?
    normalize_utf = true,
    
    -- Descomprimir PDF, SWF, ZIP, etc. (cuidado con rendimiento)
    decompress_pdf = false,
    decompress_swf = false,
    decompress_zip = false,
    decompress_vba = false,
    
    -- Profundidad de escaneo en adjuntos MIME
    max_mime_attach = 5,
    
    -- Ejemplo: bloquear (o alertar) si el cliente usa ciertos métodos
    --allowed_methods = 'GET,POST,HEAD,OPTIONS',
    --disallowed_methods = 'DELETE,TRACE,TRACK' 
    -- (Solo actívalo si estás seguro de que tu app no requiere esos métodos)
    
    -- Manejo de + como espacio en URIs
    plus_to_space = true
}


http2_inspect = { }

-- see file_magic.rules for file id rules
file_id = { rules_file = 'file_magic.rules' }
file_policy = { }

js_norm = default_js_norm

-- the following require additional configuration to be fully effective:

appid =
{
    -- appid requires this to use appids in rules
    --app_detector_dir = 'directory to load appid detectors from'
}

--[[
reputation =
{
    -- configure one or both of these, then uncomment reputation
    -- (see also related path vars at the top of snort_defaults.lua)

    --blacklist = 'blacklist file name with ip lists'
    --whitelist = 'whitelist file name with ip lists'
}
--]]

reputation = {
    blocklist = 'blocklist.rules',
    -- allowlist no es obligatoria ahora, pero se pueden hacer excepciones
    list_dir = '/usr/local/snort/etc/snort/reputation',
    memcap = 500,
    nested_ip = 'inner',
    priority = 'allowlist',
    scan_local = false,
    allow = 'do_not_block',
}


---------------------------------------------------------------------------
-- 3. configure bindings
---------------------------------------------------------------------------

wizard = default_wizard

binder =
{
    -- port bindings required for protocols without wizard support
    { when = { proto = 'udp', ports = '53', role='server' },  use = { type = 'dns' } },
    { when = { proto = 'tcp', ports = '53', role='server' },  use = { type = 'dns' } },
    { when = { proto = 'tcp', ports = '111', role='server' }, use = { type = 'rpc_decode' } },
    { when = { proto = 'tcp', ports = '502', role='server' }, use = { type = 'modbus' } },
    { when = { proto = 'tcp', ports = '2123 2152 3386', role='server' }, use = { type = 'gtp_inspect' } },
    { when = { proto = 'tcp', ports = '2404', role='server' }, use = { type = 'iec104' } },
    { when = { proto = 'udp', ports = '2222', role = 'server' }, use = { type = 'cip' } },
    { when = { proto = 'tcp', ports = '44818', role = 'server' }, use = { type = 'cip' } },

    { when = { proto = 'tcp', service = 'dcerpc' },  use = { type = 'dce_tcp' } },
    { when = { proto = 'udp', service = 'dcerpc' },  use = { type = 'dce_udp' } },
    { when = { proto = 'udp', service = 'netflow' }, use = { type = 'netflow' } },

    { when = { service = 'netbios-ssn' },      use = { type = 'dce_smb' } },
    { when = { service = 'dce_http_server' },  use = { type = 'dce_http_server' } },
    { when = { service = 'dce_http_proxy' },   use = { type = 'dce_http_proxy' } },

    { when = { service = 'cip' },              use = { type = 'cip' } },
    { when = { service = 'dnp3' },             use = { type = 'dnp3' } },
    { when = { service = 'dns' },              use = { type = 'dns' } },
    { when = { service = 'ftp' },              use = { type = 'ftp_server' } },
    { when = { service = 'ftp-data' },         use = { type = 'ftp_data' } },
    { when = { service = 'gtp' },              use = { type = 'gtp_inspect' } },
    { when = { service = 'imap' },             use = { type = 'imap' } },
    { when = { service = 'http' },             use = { type = 'http_inspect' } },
    { when = { service = 'http2' },            use = { type = 'http2_inspect' } },
    { when = { service = 'iec104' },           use = { type = 'iec104' } },
    { when = { service = 'mms' },              use = { type = 'mms' } },
    { when = { service = 'modbus' },           use = { type = 'modbus' } },
    { when = { service = 'pop3' },             use = { type = 'pop' } },
    { when = { service = 'ssh' },              use = { type = 'ssh' } },
    { when = { service = 'sip' },              use = { type = 'sip' } },
    { when = { service = 'smtp' },             use = { type = 'smtp' } },
    { when = { service = 'ssl' },              use = { type = 'ssl' } },
    { when = { service = 'sunrpc' },           use = { type = 'rpc_decode' } },
    { when = { service = 's7commplus' },       use = { type = 's7commplus' } },
    { when = { service = 'telnet' },           use = { type = 'telnet' } },

    { use = { type = 'wizard' } },

    { 
      when = { proto = 'tcp', ports = '80 443', role = 'server' }, 
      use  = { type = 'http_inspect' } 
    },

    { when = { service = 'ssl' }, use = { type = 'ssl' } }
}

---------------------------------------------------------------------------
-- 4. configure performance
---------------------------------------------------------------------------

-- use latency to monitor / enforce packet and rule thresholds
--latency = { }

-- use these to capture perf data for analysis and tuning
--profiler = { }
--perf_monitor = { }

---------------------------------------------------------------------------
-- 5. configure detection
---------------------------------------------------------------------------

references = default_references
classifications = default_classifications

ips =
{
    -- use this to enable decoder and inspector alerts
    --enable_builtin_rules = true,

    -- use include for rules files; be sure to set your path
    -- note that rules files can include other rules files
    -- (see also related path vars at the top of snort_defaults.lua)
 rules = [[
         include /usr/local/snort/etc/snort/snort3-community-rules/snort3-community.rules
         include /usr/local/snort/etc/snort/custom.rules
     ]],

    variables = default_variables
}

-- use these to configure additional rule actions
-- react = { }
-- reject = { }

-- use this to enable payload injection utility
-- payload_injector = { }

---------------------------------------------------------------------------
-- 6. configure filters
---------------------------------------------------------------------------

-- below are examples of filters
-- each table is a list of records

--[[
suppress =
{
    -- don't want to any of see these
    { gid = 1, sid = 1 },

    -- don't want to see anything for a given host
    { track = 'by_dst', ip = '1.2.3.4' }

    -- don't want to see these for a given host
    { gid = 1, sid = 2, track = 'by_dst', ip = '1.2.3.4' },
}
--]]

--[[
event_filter =
{
    -- reduce the number of events logged for some rules
    { gid = 1, sid = 1, type = 'limit', track = 'by_src', count = 2, seconds = 10 },
    { gid = 1, sid = 2, type = 'both',  track = 'by_dst', count = 5, seconds = 60 },
}
--]]

--[[
rate_filter =
{
    -- alert on connection attempts from clients in SOME_NET
    { gid = 135, sid = 1, track = 'by_src', count = 5, seconds = 1,
      new_action = 'alert', timeout = 4, apply_to = '[$SOME_NET]' },

    -- alert on connections to servers over threshold
    { gid = 135, sid = 2, track = 'by_dst', count = 29, seconds = 3,
      new_action = 'alert', timeout = 1 },
}
--]]

---------------------------------------------------------------------------
-- 7. configure outputs
---------------------------------------------------------------------------

-- event logging
-- you can enable with defaults from the command line with -A <alert_type>
-- uncomment below to set non-default configs
--alert_csv = { }
--alert_fast = { }
--alert_full = { }
--alert_sfsocket = { }
--alert_syslog = { }
--unified2 = { }

-- packet logging
-- you can enable with defaults from the command line with -L <log_type>
--log_codecs = { }
--log_hext = { }
--log_pcap = { }

-- additional logs
--packet_capture = { }
--file_log = { }

---------------------------------------------------------------------------
-- 8. configure tweaks
---------------------------------------------------------------------------

if ( tweaks ~= nil ) then
    include(tweaks .. '.lua')
end