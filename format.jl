using Runic

for (root, dirs, files) in walkdir(@__DIR__)
    for file in files
        if endswith(file, ".jl")
            Runic.format_file(joinpath(root, file); inplace = true)
        end
    end
end
