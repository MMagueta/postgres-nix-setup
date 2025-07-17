{ pkgs, lib, ... }:
pkgs.buildGoModule rec {
  pname = "supabase-cli";
  version = "2.1.1";
  
  src = pkgs.fetchFromGitHub {
    owner = "supabase";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-jTAYdAJTaQhDKVwor1rj3ZhyAZ88ElvznFv5nncf4m8=";
  };
  
  vendorHash = "sha256-WygbrpE+FIWBs2Q34EAFlOm458vqnuIy+seZb+4Wf+I=";

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/supabase/cli/internal/utils.Version=${version}"
  ];

  doCheck = false; # tests are trying to connect to localhost

  nativeBuildInputs = [ pkgs.installShellFiles ];

  postInstall = ''
    rm $out/bin/{docs,listdep}
    mv $out/bin/{cli,supabase}

    installShellCompletion --cmd supabase \
      --bash <($out/bin/supabase completion bash) \
      --fish <($out/bin/supabase completion fish) \
      --zsh <($out/bin/supabase completion zsh)
  '';

  meta = with lib; {
    description = "CLI for interacting with supabase";
    homepage = "https://github.com/supabase/cli";
    license = licenses.mit;
    mainProgram = "supabase";
  };
}
