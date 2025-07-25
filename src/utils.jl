@data Verbosity begin
    None
    Info
    Warn
    Error
    Level(Int)
    Edge
    All
    Default
    Code(Expr)
end

""" 
AbstractVerbositySpecifier{T}
Base for types which specify which log messages are emitted at what level.
"""
abstract type AbstractVerbositySpecifier{T} end




# Utilities 

function message_level(verbose::AbstractVerbositySpecifier{true}, option, group)
    group = getproperty(verbose, group)
    opt_level = getproperty(group, option)

    @match opt_level begin
        Verbosity.Code(expr) => expr
        Verbosity.None() => nothing
        Verbosity.Info() => Logging.Info
        Verbosity.Warn() => Logging.Warn
        Verbosity.Error() => Logging.Error
        Verbosity.Level(i) => Logging.LogLevel(i)
    end
end

function emit_message(
    f::Function, verbose::V, option, group, file, line,
    _module) where {V<:AbstractVerbositySpecifier{true}}
    level = message_level(
        verbose, option, group)
        
    if level isa Expr
        level
    elseif !isnothing(level)
        message = f()
        Base.@logmsg level message _file = file _line = line _module = _module
    end
end

function emit_message(message::String, verbose::V,
    option, group, file, line, _module) where {V<:AbstractVerbositySpecifier{true}}
    level = message_level(verbose, option, group)

    if !isnothing(level)
        Base.@logmsg level message _file = file _line = line _module = _module _group = group
    end
end

function emit_message(
    f, verbose::AbstractVerbositySpecifier{false}, option, group, file, line, _module)
end

"""
A macro that emits a log message based on the log level specified in the `option` and `group` of the `AbstractVerbositySpecifier` supplied. 
    
`f_or_message` may be a message String, or a 0-argument function that returns a String. 

## Usage
To emit a simple string, `@SciMLMessage("message", verbosity, :option, :group)` will emit a log message with the LogLevel specified in `verbosity`, at the appropriate `option` and `group`. 

`@SciMLMessage` can also be used to emit a log message coming from the evaluation of a 0-argument function. This function is resolved in the environment of the macro call.
Therefore it can use variables from the surrounding environment. This may be useful if the log message writer wishes to carry out some calculations using existing variables
and use them in the log message.

```julia
x = 10
y = 20

@SciMLMessage(verbosity, :option, :group) do 
    z = x + y
    "Message is: x + y = \$z"
end
```
"""
macro SciMLMessage(f_or_message, verb, option, group)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    return :(emit_message(
        $(esc(f_or_message)), $(esc(verb)), $option, $group, $file, $line, $_module))
end

"""
        `verbosity_to_int(verb::Verbosity.Type)`
    Takes a `Verbosity.Type` and gives a corresponding integer value. 
    Verbosity settings that use integers or enums that hold integers are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity. Each of the basic verbosity levels
    are mapped to an integer. 

    - None() => 0
    - Info() => 1
    - Warn() => 2
    - Error() => 3
    - Level(i) => i
"""
function verbosity_to_int(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => 0
        Verbosity.Info() => 1
        Verbosity.Warn() => 2
        Verbosity.Error() => 3
        Verbosity.Level(i) => i
    end
end

"""
        `verbosity_to_bool(verb::Verbosity.Type)`
    Takes a `Verbosity.Type` and gives a corresponding boolean value.
    Verbosity settings that use booleans are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity.
    If the verbosity is `Verbosity.None`, then `false` is returned. Otherwise, `true` is returned.
"""
function verbosity_to_bool(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => false
        _ => true
    end
end





function SciMLLogger(; info_repl=true, warn_repl=true, error_repl=true,
    info_file=nothing, warn_file=nothing, error_file=nothing)
    info_sink = isnothing(info_file) ? NullLogger() : FileLogger(info_file)
    warn_sink = isnothing(warn_file) ? NullLogger() : FileLogger(warn_file)
    error_sink = isnothing(error_file) ? NullLogger() : FileLogger(error_file)

    repl_filter = EarlyFilteredLogger(current_logger()) do log
        if log.level == Logging.Info && info_repl
            return true
        end

        if log.level == Logging.Warn && warn_repl
            return true
        end

        if log.level == Logging.Error && error_repl
            return true
        end

        return false
    end

    info_filter = EarlyFilteredLogger(info_sink) do log
        log.level == Logging.Info
    end

    warn_filter = EarlyFilteredLogger(warn_sink) do log
        log.level == Logging.Warn
    end

    error_filter = EarlyFilteredLogger(error_sink) do log
        log.level == Logging.Error
    end

    TeeLogger(repl_filter, info_filter, warn_filter, error_filter)
end