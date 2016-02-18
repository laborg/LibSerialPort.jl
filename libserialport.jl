type SPPort end
type SPConfig end
type SPEventSet end

typealias Port    Ref{SPPort}
typealias PortP   Ref{Ptr{SPPort}}
typealias Config  Ref{SPConfig}
typealias ConfigP Ref{Ptr{SPConfig}}

@enum(SPReturn,
    SP_OK = 0,
    SP_ERR_ARG = -1,
    SP_ERR_FAIL = -2,
    SP_ERR_MEM = -3,
    SP_ERR_SUPP = -4)

@enum(SPMode,
    SP_MODE_READ = 1,
    SP_MODE_WRITE = 2,
    SP_MODE_READ_WRITE = 3)

@enum(SPEvent,
    SP_EVENT_RX_READY = 1,
    SP_EVENT_TX_READY = 2,
    SP_EVENT_ERROR = 4)

@enum(SPBuffer,
    SP_BUF_INPUT = 1,
    SP_BUF_OUTPUT = 2,
    SP_BUF_BOTH = 3)

@enum(SPParity,
    SP_PARITY_INVALID = -1,
    SP_PARITY_NONE = 0,
    SP_PARITY_ODD = 1,
    SP_PARITY_EVEN = 2,
    SP_PARITY_MARK = 3,
    SP_PARITY_SPACE = 4)

@enum(SPrts,
    SP_RTS_INVALID = -1,
    SP_RTS_OFF = 0,
    SP_RTS_ON = 1,
    SP_RTS_FLOW_CONTROL = 2)

@enum(SPcts,
    SP_CTS_INVALID = -1,
    SP_CTS_IGNORE = 0,
    SP_CTS_FLOW_CONTROL = 1)

@enum(SPdtr,
    SP_DTR_INVALID = -1,
    SP_DTR_OFF = 0,
    SP_DTR_ON = 1,
    SP_DTR_FLOW_CONTROL = 2)

@enum(SPdsr,
    SP_DSR_INVALID = -1,
    SP_DSR_IGNORE = 0,
    SP_DSR_FLOW_CONTROL = 1)

@enum(SPXonXoff,
    SP_XONXOFF_INVALID = -1,
    SP_XONXOFF_DISABLED = 0,
    SP_XONXOFF_IN = 1,
    SP_XONXOFF_OUT = 2,
    SP_XONXOFF_INOUT = 3)

@enum(SPFlowControl,
    SP_FLOWCONTROL_NONE = 0,
    SP_FLOWCONTROL_XONXOFF = 1,
    SP_FLOWCONTROL_RTSCTS = 2,
    SP_FLOWCONTROL_DTRDSR = 3)

@enum(SPSignal,
    SP_SIG_CTS = 1,
    SP_SIG_DSR = 2,
    SP_SIG_DCD = 4,
    SP_SIG_RI = 8)

@enum(SPTransport,
    SP_TRANSPORT_NATIVE,
    SP_TRANSPORT_USB,
    SP_TRANSPORT_BLUETOOTH)

function notify_on_error(ret::SPReturn)
    ret >= SP_OK && return

    msg = "libserialport returned $ret - "

    if ret == SP_ERR_ARG
        msg *= "Function was called with invalid arguments."
    elseif ret == SP_ERR_FAIL
        msg *= "Host OS reported a failure. Error code/message provided by the OS "
        msg *= "can be obtained by calling sp_last_error_code() or sp_last_error_message()."
    elseif ret == SP_ERR_MEM
        msg *= "Memory allocation failed."
    elseif ret == SP_ERR_SUPP
        msg *= "No support for the requested operation in the current OS, driver or device."
    else
        error("Unknown SPReturn value")
    end

    error(msg)
end

# enum sp_return sp_get_port_by_name(const char *portname, struct sp_port **port_ptr);
function sp_get_port_by_name(portname::AbstractString)
    portp = PortP()
    ret = ccall((:sp_get_port_by_name, "libserialport"), SPReturn,
                (Ptr{UInt8}, PortP), portname, portp)
    notify_on_error(ret)
    portp[]
end

# void sp_free_port(struct sp_port *port);
function sp_free_port(port::Port)
    ccall((:sp_free_port, "libserialport"), Void, (Port,), port)
end

# enum sp_return sp_list_ports(struct sp_port ***list_ptr);
function sp_list_ports()
    ports = Ref{Ptr{Ptr{SPPort}}}()
    ret = ccall((:sp_list_ports, "libserialport"),
                SPReturn, (Ref{Ptr{Ptr{SPPort}}},), ports)
    notify_on_error(ret)
    return ports[]
end

# enum sp_return sp_copy_port(const struct sp_port *port, struct sp_port **copy_ptr);
function sp_copy_port(port::Port)
    port_copy = PortP()
    ret = ccall((:sp_copy_port, "libserialport"), SPReturn,
                (Port, PortP), port, port_copy)
    notify_on_error(ret)
    return port_copy[]
end

# void sp_free_port_list(struct sp_port **ports);
function sp_free_port_list(ports::PortP)
    ccall((:sp_free_port_list, "libserialport"), Void, (PortP,), ports)
end

# enum sp_return sp_open(struct sp_port *port, enum sp_mode flags);
function sp_open(port::Port, mode::SPMode)
    ret = ccall((:sp_open, "libserialport"), SPReturn, (Port, SPMode), port, mode)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_close(struct sp_port *port);
function sp_close(port::Port)
    ret = ccall((:sp_close, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# char *sp_get_port_name(const struct sp_port *port);
function sp_get_port_name(port::Port)
    cname = ccall((:sp_get_port_name, "libserialport"), Ptr{UInt8}, (Port,), port)
    name = cname != C_NULL ? bytestring(cname) : ""
end

# char *sp_get_port_description(const struct sp_port *port);
function sp_get_port_description(port::Port)
    d = ccall((:sp_get_port_description, "libserialport"), Ptr{UInt8}, (Port,), port)
    desc = d != C_NULL ? bytestring(d) : ""
end

# enum sp_transport sp_get_port_transport(const struct sp_port *port);
function sp_get_port_transport(port::Port)
    ccall((:sp_get_port_transport, "libserialport"), SPTransport, (Port,), port)
end

# enum sp_return sp_get_port_usb_bus_address(const struct sp_port *port, int *usb_bus, int *usb_address);
function sp_get_port_usb_bus_address(port::Port)

    if sp_get_port_transport(port) != SP_TRANSPORT_USB
        warn("Port does not use USB transport")
        return
    end

    usb_bus = Ref{Cint}()
    usb_address = Ref{Cint}()
    ret = ccall((:sp_get_port_usb_bus_address, "libserialport"), SPReturn,
                (Port, Ref{Cint}, Ref{Cint}), port, usb_bus, usb_address)

    if ret == SP_ERR_SUPP
        return -1, -1
    end

    notify_on_error(ret)
    return usb_bus[], usb_address[]
end

# enum sp_return sp_get_port_usb_vid_pid(const struct sp_port *port, int *usb_vid, int *usb_pid);
function sp_get_port_usb_vid_pid(port::Port)

    if sp_get_port_transport(port) != SP_TRANSPORT_USB
        warn("Port does not use USB transport")
        return
    end

    vid = Ref{Cint}()
    pid = Ref{Cint}()
    ret = ccall((:sp_get_port_usb_vid_pid, "libserialport"), SPReturn,
                (Port, Ref{Cint}, Ref{Cint}), port, vid, pid)

    if ret == SP_ERR_SUPP
        return -1, -1
    end

    notify_on_error(ret)
    return vid[], pid[]
end

# char *sp_get_port_usb_manufacturer(const struct sp_port *port);
function sp_get_port_usb_manufacturer(port::Port)
    m = ccall((:sp_get_port_usb_manufacturer, "libserialport"),
              Ptr{UInt8}, (Port,), port)
    manufacturer = (m != C_NULL) ? bytestring(m) : ""
end

# char *sp_get_port_usb_product(const struct sp_port *port);
function sp_get_port_usb_product(port::Port)
    p = ccall((:sp_get_port_usb_product, "libserialport"),
              Ptr{UInt8}, (Port,), port)
    product = (p != C_NULL) ? bytestring(p) : ""
end

# char *sp_get_port_usb_serial(const struct sp_port *port);
function sp_get_port_usb_serial(port::Port)
    s = ccall((:sp_get_port_usb_serial, "libserialport"),
              Ptr{UInt8}, (Port,), port)
    serial = (s != C_NULL) ? bytestring(s) : ""
end

# char *sp_get_port_bluetooth_address(const struct sp_port *port);
function sp_get_port_bluetooth_address(port::Port)
    a = ccall((:sp_get_port_bluetooth_address, "libserialport"),
              Ptr{UInt8}, (Port,), port)
    address = (a != C_NULL) ? bytestring(a) : ""
end

# enum sp_return sp_get_port_handle(const struct sp_port *port, void *result_ptr);
function sp_get_port_handle(port::Port)
    # For Linux and OS X
    result = Ref{Cint}(0)

    # TODO: on Windows, result should be Ref{HANDLE}

    ret = ccall((:sp_get_port_handle, "libserialport"), SPReturn,
                (Port, Ref{Cint}), port, result)
    notify_on_error(ret)
    result[]
end

# enum sp_return sp_new_config(struct sp_port_config **config_ptr);
function sp_new_config()
    pc = ConfigP()
    ret = ccall((:sp_new_config, "libserialport"), SPReturn, (ConfigP,), pc)
    notify_on_error(ret)
    pc[]
end

# void sp_free_config(struct sp_port_config *config);
function sp_free_config(config::Config)
    ccall((:sp_free_config, "libserialport"), Void, (Config,), config)
end

function sp_get_config(port::Port)
    config = sp_new_config()
    ret = ccall((:sp_get_config, "libserialport"), SPReturn,
                (Port, Config), port, config)
    notify_on_error(ret)
    config
end

# enum sp_return sp_set_config(struct sp_port *port, const struct sp_port_config *config);
function sp_set_config(port::Port, config::Config)
    ret = ccall((:sp_set_config, "libserialport"), SPReturn,
                (Port, Config), port, config)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_baudrate(struct sp_port *port, int baudrate);
function sp_set_baudrate(port::Port, baudrate::Integer)
    ret = ccall((:sp_set_baudrate, "libserialport"), SPReturn,
                (Port, Cint), port, Cint(baudrate))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_baudrate(const struct sp_port_config *config, int *baudrate_ptr);
function sp_get_config_baudrate(config::Config)
    baudrate = Ref{Cint}()
    ret = ccall((:sp_get_config_baudrate, "libserialport"), SPReturn,
                (Config, Ref{Cint}), config, baudrate)
    notify_on_error(ret)
    baudrate[]
end

# enum sp_return sp_set_config_baudrate(struct sp_port_config *config, int baudrate);
function sp_set_config_baudrate(config::Config, baudrate::Integer)
    ret = ccall((:sp_set_config_baudrate, "libserialport"), SPReturn,
                (Config, Cint), config, Cint(baudrate))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_bits(struct sp_port *port, int bits);
function sp_set_bits(port::Port, bits::Integer)
    @assert 5 <= bits <= 8
    ret = ccall((:sp_set_bits, "libserialport"), SPReturn,
                (Port, Cint), port, Cint(bits))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_bits(const struct sp_port_config *config, int *bits_ptr);
function sp_get_config_bits(config::Config)
    bits = Ref{Cint}()
    ret = ccall((:sp_get_config_bits, "libserialport"), SPReturn,
                (Config, Ref{Cint}), config, bits)
    notify_on_error(ret)
    bits[]
end

# enum sp_return sp_set_config_bits(struct sp_port_config *config, int bits);
function sp_set_config_bits(config::Config, bits::Integer)
    ret = ccall((:sp_set_config_bits, "libserialport"), SPReturn,
                (Config, Cint), config, Cint(bits))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_parity(struct sp_port *port, enum sp_parity parity);
function sp_set_parity(port::Port, parity::SPParity)
    ret = ccall((:sp_set_parity, "libserialport"), SPReturn,
                (Port, SPParity), port, parity)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_parity(const struct sp_port_config *config, enum sp_parity *parity_ptr);
function sp_get_config_parity(config::Config)
    parity = Ref{SPParity}()
    ret = ccall((:sp_get_config_parity, "libserialport"), SPReturn,
                (Config, Ref{SPParity}), config, parity)
    notify_on_error(ret)
    parity[]
end

# enum sp_return sp_set_config_parity(struct sp_port_config *config, enum sp_parity parity);
function sp_set_config_parity(config::Config, parity::SPParity)
    ret = ccall((:sp_set_config_parity, "libserialport"), SPReturn,
                (Config, SPParity), config, parity)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_stopbits(struct sp_port *port, int stopbits);
function sp_set_stopbits(port::Port, stopbits::Integer)
    ret = ccall((:sp_set_stopbits, "libserialport"), SPReturn,
                (Port, Cint), port, Cint(stopbits))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_stopbits(const struct sp_port_config *config, int *stopbits_ptr);
function sp_get_config_stopbits(config::Config)
    bits = Ref{Cint}()
    ret = ccall((:sp_get_config_stopbits, "libserialport"), SPReturn,
                (Config, Ref{Cint}), config, bits)
    notify_on_error(ret)
    bits[]
end

# enum sp_return sp_set_config_stopbits(struct sp_port_config *config, int stopbits);
function sp_set_config_stopbits(config::Config, stopbits::Integer)
    ret = ccall((:sp_set_config_stopbits, "libserialport"), SPReturn,
                (Config, Cint), config, Cint(stopbits))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_rts(struct sp_port *port, enum sp_rts rts);
function sp_set_rts(port::Port, rts::SPrts)
    ret = ccall((:sp_set_rts, "libserialport"), SPReturn,
                (Port, SPrts), port, rts)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_rts(const struct sp_port_config *config, enum sp_rts *rts_ptr);
function sp_get_config_rts(config::Config)
    rts = Ref{SPrts}()
    ret = ccall((:sp_get_config_rts, "libserialport"), SPReturn,
                (Config, Ref{SPrts}), config, rts)
    notify_on_error(ret)
    rts[]
end

# enum sp_return sp_set_config_rts(struct sp_port_config *config, enum sp_rts rts);
function sp_set_config_rts(config::Config, rts::SPrts)
    ret = ccall((:sp_set_config_rts, "libserialport"), SPReturn,
                (Config, SPrts), config, SPrts(rts))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_cts(struct sp_port *port, enum sp_cts cts);
function sp_set_cts(port::Port, cts::SPcts)
    ret = ccall((:sp_set_cts, "libserialport"), SPReturn,
                (Port, SPcts), port, cts)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_cts(const struct sp_port_config *config, enum sp_cts *cts_ptr);
function sp_get_config_cts(config::Config)
    cts = Ref{SPcts}()
    ret = ccall((:sp_get_config_cts, "libserialport"), SPReturn,
                (Config, Ref{SPcts}), config, cts)
    notify_on_error(ret)
    cts[]
end

# enum sp_return sp_set_config_cts(struct sp_port_config *config, enum sp_cts cts);
function sp_set_config_cts(config::Config, cts::SPcts)
    ret = ccall((:sp_set_config_cts, "libserialport"), SPReturn,
                (Config, SPcts), config, SPcts(cts))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_dtr(struct sp_port *port, enum sp_dtr dtr);
function sp_set_dtr(port::Port, dtr::SPdtr)
    ret = ccall((:sp_set_dtr, "libserialport"), SPReturn,
                (Port, SPdtr), port, dtr)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_dtr(const struct sp_port_config *config, enum sp_dtr *dtr_ptr);
function sp_get_config_dtr(config::Config)
    dtr = Ref{SPdtr}()
    ret = ccall((:sp_get_config_dtr, "libserialport"), SPReturn,
                (Config, Ref{SPdtr}), config, dtr)
    notify_on_error(ret)
    dtr[]
end

# enum sp_return sp_set_config_dtr(struct sp_port_config *config, enum sp_dtr dtr);
function sp_set_config_dtr(config::Config, dtr::SPdtr)
    ret = ccall((:sp_set_config_dtr, "libserialport"), SPReturn,
                (Config, SPdtr), config, SPdtr(dtr))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_dsr(struct sp_port *port, enum sp_dsr dsr);
function sp_set_dsr(port::Port, dsr::SPdsr)
    ret = ccall((:sp_set_dsr, "libserialport"), SPReturn,
                (Port, SPdsr), port, dsr)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_dsr(const struct sp_port_config *config, enum sp_dsr *dsr_ptr);
function sp_get_config_dsr(config::Config)
    dsr = Ref{SPdsr}()
    ret = ccall((:sp_get_config_dsr, "libserialport"), SPReturn,
                (Config, Ref{SPdsr}), config, dsr)
    notify_on_error(ret)
    dsr[]
end

# enum sp_return sp_set_config_dsr(struct sp_port_config *config, enum sp_dsr dsr);
function sp_set_config_dsr(config::Config, dsr::SPdsr)
    ret = ccall((:sp_set_config_dsr, "libserialport"), SPReturn,
                (Config, SPdsr), config, SPdsr(dsr))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_xon_xoff(struct sp_port *port, enum sp_xonxoff xon_xoff);
function sp_set_xon_xoff(port::Port, xon_xoff::SPXonXoff)
    ret = ccall((:sp_set_xon_xoff, "libserialport"), SPReturn,
                (Port, SPXonXoff), port, xon_xoff)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_config_xon_xoff(const struct sp_port_config *config, enum sp_xonxoff *xon_xoff_ptr);
function sp_get_config_xon_xoff(config::Config)
    xon_xoff = Ref{SPXonXoff}()
    ret = ccall((:sp_get_config_xon_xoff, "libserialport"), SPReturn,
                (Config, Ref{SPXonXoff}), config, xon_xoff)
    notify_on_error(ret)
    xon_xoff[]
end

# enum sp_return sp_set_config_xon_xoff(struct sp_port_config *config, enum sp_xonxoff xon_xoff);
function sp_set_config_xon_xoff(config::Config, xon_xoff::SPXonXoff)
    ret = ccall((:sp_set_config_xon_xoff, "libserialport"), SPReturn,
                (Config, SPXonXoff), config, SPXonXoff(xon_xoff))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_config_flowcontrol(struct sp_port_config *config, enum sp_flowcontrol flowcontrol);
function sp_set_config_flowcontrol(config::Config, flowcontrol::SPFlowControl)
    ret = ccall((:sp_set_config_flowcontrol, "libserialport"), SPReturn,
                (Config, SPFlowControl), config, flowcontrol)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_set_flowcontrol(struct sp_port *port, enum sp_flowcontrol flowcontrol);
function sp_set_flowcontrol(port::Port, flowcontrol::SPFlowControl)
    ret = ccall((:sp_set_flowcontrol, "libserialport"), SPReturn,
                (Port, SPFlowControl), port, flowcontrol)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_blocking_read(struct sp_port *port, void *buf, size_t count, unsigned int timeout_ms);
function sp_blocking_read(port::Port, nbytes::Integer, timeout_ms::Integer)
    buffer = Array(UInt8, nbytes)

    # If the read succeeds, the return value is the number of bytes read.
    ret = ccall((:sp_blocking_read, "libserialport"), SPReturn,
                (Port, Ptr{UInt8}, Csize_t, Cuint),
                port, buffer, sizeof(buffer), Cuint(timeout_ms))
    notify_on_error(ret)

    return bytestring(pointer(buffer), Int(ret) + 1)
end

# enum sp_return sp_blocking_read_next(struct sp_port *port, void *buf, size_t count, unsigned int timeout_ms);
function sp_blocking_read_next(port::Port, nbytes::Integer, timeout_ms::Integer)
    buffer = Array(UInt8, nbytes)

    # If the read succeeds, the return value is the number of bytes read.
    ret = ccall((:sp_blocking_read_next, "libserialport"), SPReturn,
                (Port, Ptr{UInt8}, Csize_t, Cuint),
                port, buffer, sizeof(buffer), Cuint(timeout_ms))
    notify_on_error(ret)

    return bytestring(pointer(buffer), Int(ret) + 1)
end

# enum sp_return sp_nonblocking_read(struct sp_port *port, void *buf, size_t count);
function sp_nonblocking_read(port::Port, nbytes::Integer)
    buffer = Array(UInt8, nbytes)
    ret = ccall((:sp_nonblocking_read, "libserialport"), SPReturn,
                (Port, Ptr{UInt8}, Csize_t), port, buffer, sizeof(buffer))
    notify_on_error(ret)

    return bytestring(pointer(buffer), Int(ret) + 1)
end

# enum sp_return sp_blocking_write(struct sp_port *port, const void *buf, size_t count, unsigned int timeout_ms);
function sp_blocking_write(port::Port, buffer::Array{UInt8}, timeout_ms::Integer)
    ret = ccall((:sp_blocking_write, "libserialport"), SPReturn,
                (Port, Ptr{UInt8}, Csize_t, Cuint),
                port, pointer(buffer), sizeof(buffer), Cuint(timeout_ms))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_nonblocking_write(struct sp_port *port, const void *buf, size_t count);
function sp_nonblocking_write(port::Port, buffer::Array{UInt8})
    ret = ccall((:sp_nonblocking_write, "libserialport"), SPReturn,
                (Port, Ptr{UInt8}, Csize_t), port, pointer(buffer), sizeof(buffer))
    notify_on_error(ret)
    ret
end

# enum sp_return sp_input_waiting(struct sp_port *port);
"""
Returns the number of bytes in the input buffer or an error code.
"""
function sp_input_waiting(port::Port)
    ret = ccall((:sp_input_waiting, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_output_waiting(struct sp_port *port);
"""
Returns the number of bytes in the output buffer or an error code.
"""
function sp_output_waiting(port::Port)
    ret = ccall((:sp_output_waiting, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_flush(struct sp_port *port, enum sp_buffer buffers);
function sp_flush(port::Port, buffers::SPBuffer)
    ret = ccall((:sp_flush, "libserialport"), SPReturn,
                (Port, SPBuffer), port, buffers)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_drain(struct sp_port *port);
function sp_drain(port::Port)
    ret = ccall((:sp_drain, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_new_event_set(struct sp_event_set **result_ptr);
function sp_new_event_set()
    event_set = Ref{Ptr{SPEventSet}}()
    ret = ccall((:sp_new_event_set, "libserialport"), SPReturn,
                (Ref{Ptr{SPEventSet}},), event_set)
    notify_on_error(ret)
    event_set[]
end

# enum sp_return sp_add_port_events(struct sp_event_set *event_set, const struct sp_port *port, enum sp_event mask);
function sp_add_port_events(event_set::Ref{SPEventSet}, port::Port, mask::SPEvent)
    ret = ccall((:sp_add_port_events, "libserialport"), SPReturn,
                (Ref{SPEventSet}, Port, SPEvent), event_set, port, mask)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_wait(struct sp_event_set *event_set, unsigned int timeout_ms);
function sp_wait(event_set::Ref{SPEventSet}, timeout_ms::Integer)
    ret = ccall((:sp_wait, "libserialport"), SPReturn,
                (Ref{SPEventSet}, Cuint), event_set, timeout_ms)
    notify_on_error(ret)
    ret
end

# void sp_free_event_set(struct sp_event_set *event_set);
function sp_free_event_set(event_set::Ref{SPEventSet})
    ret = ccall((:sp_free_event_set, "libserialport"), SPReturn,
                (Ref{SPEventSet},), event_set)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_get_signals(struct sp_port *port, enum sp_signal *signal_mask);
function sp_get_signals(port::Port, signal_mask::Ref{SPSignal})
    ret = ccall((:sp_get_signals, "libserialport"), SPReturn,
                (Port, Ref{SPSignal}), port, signal_mask)
    notify_on_error(ret)
    signal_mask[]
end

# enum sp_return sp_start_break(struct sp_port *port);
function sp_start_break(port::Port)
    ret = ccall((:sp_start_break, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# enum sp_return sp_end_break(struct sp_port *port);
function sp_end_break(port::Port)
    ret = ccall((:sp_end_break, "libserialport"), SPReturn, (Port,), port)
    notify_on_error(ret)
    ret
end

# int sp_last_error_code(void);
function sp_last_error_code()
    ccall((:sp_last_error_code, "libserialport"), Cint, ())
end

# char *sp_last_error_message(void);
function sp_last_error_message()
    msg = ccall((:sp_last_error_message, "libserialport"), Ptr{UInt8}, ())
    msg_jl = bytestring(msg)
    sp_free_error_message(msg)
    return msg_jl
end

# void sp_free_error_message(char *message);
function sp_free_error_message(message::Ptr{UInt8})
    ccall((:sp_free_error_message, "libserialport"), Void, (Ptr{UInt8},), message)
end

# Due to ccall's incomplete variadic argument support, the following two
# functions are not (yet) wrapped.
# void sp_set_debug_handler(void (*handler)(const char *format, ...));
# void sp_default_debug_handler(const char *format, ...);

# int sp_get_major_package_version(void);
function sp_get_major_package_version()
    ccall((:sp_get_major_package_version, "libserialport"), Cint, ())
end

# int sp_get_minor_package_version(void);
function sp_get_minor_package_version()
    ccall((:sp_get_minor_package_version, "libserialport"), Cint, ())
end

# int sp_get_micro_package_version(void);
function sp_get_micro_package_version()
    ccall((:sp_get_micro_package_version, "libserialport"), Cint, ())
end

# const char *sp_get_package_version_string(void);
function sp_get_package_version_string()
    ver = ccall((:sp_get_package_version_string, "libserialport"), Ptr{UInt8}, ())
    bytestring(ver)
end

# int sp_get_current_lib_version(void);
function sp_get_current_lib_version()
    ccall((:sp_get_current_lib_version, "libserialport"), Cint, ())
end

# int sp_get_revision_lib_version(void);
function sp_get_revision_lib_version()
    ccall((:sp_get_revision_lib_version, "libserialport"), Cint, ())
end

# int sp_get_age_lib_version(void);
function sp_get_age_lib_version()
    ccall((:sp_get_age_lib_version, "libserialport"), Cint, ())
end

# const char *sp_get_lib_version_string(void);
function sp_get_lib_version_string()
    ver = ccall((:sp_get_lib_version_string, "libserialport"), Ptr{UInt8}, ())
    bytestring(ver)
end
