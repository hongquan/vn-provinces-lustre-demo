dev-serve $ERL_FLAGS="+B":
    gleam run -m lustre/dev start

build:
    gleam run -m lustre/dev build
