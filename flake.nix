{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
      PGHOSTADDR = "127.0.0.1";
      PGUSER = "admin";
      PGDATABASE = "supabase";
      PGPASSWORD = "admin";
      PGPORT = 5433;
    in
      {
        packages = forAllSystems (system:
          let
            _pkgs = nixpkgs.legacyPackages."${system}";
          in {
            devenv-up = self.devShells.${system}.services.config.procfileScript;
          });

      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          supabase = "${pkgs.callPackage ./deps/supabase-cli.nix { pkgs = pkgs;}}/bin/supabase";
          psql = "${pkgs.postgresql_15}/bin/psql";
          # Source files, order is relevant since SQL has no forward
          # declaration of database objects.
          files = [
            ./src/Example.sql
          ];
          # logical schemas that comprise the application. These do not
          # necessarily map to the SQL file names. This should indicate
          # the logical dependency order between the schemas.
          schemas = ["application"];
          genFileParams = builtins.foldl' (acc: elem: acc + " -f" + elem) "" files;
          schemasCommaList = pkgs.lib.strings.concatStringsSep "," schemas;
          postgresUrl = {}:''postgresql://${builtins.getEnv "PGUSER"}:${builtins.getEnv "PGPASSWORD"}@${builtins.getEnv "PGHOSTADDR"}:${builtins.getEnv "PGPORT"}/${builtins.getEnv "PGDATABASE"}'';
        in {
          setup = {
            type = "app";
            program = builtins.toString (pkgs.writeShellScript "setup-program" ''
               ${psql} -1 ${genFileParams}
            '');
          };
          build = {
            type = "app";
            program = builtins.toString (pkgs.writeShellScript "build-program" ''
            ${supabase} db diff -s ${schemasCommaList} --db-url ${postgresUrl {}} | ${supabase} migration new ${builtins.getEnv "MIGRATION_FILE"}
            '');
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          supabase-cli = pkgs.callPackage ./deps/supabase-cli.nix { pkgs = pkgs;};
        in {
          services = devenv.lib.mkShell {
            inherit pkgs inputs;
            modules = [{
              services.postgres = {
                enable = true;
                package = pkgs.postgresql_15;
                extensions =
                  p: with p; [
                    pgtap
                    pg_cron
                    pgsql-http
                    plpgsql_check
                  ];

                initdbArgs = [
                  "--locale=C"
                  "--encoding=UTF8"
                ];

                initialDatabases = [
                  { name = "supabase"; }
                ];

                port = PGPORT;
                listen_addresses = PGHOSTADDR;

                settings = {
                  "shared_preload_libraries" = "pg_cron";
                  "cron.database_name" = "supabase";
                  "cron.timezone" = "UTC";
                  # https://github.com/okbob/plpgsql_check?tab=readme-ov-file#passive-mode-only-recommended-for-development-or-preproduction
                  "plpgsql_check.mode" = "every_start";
                  "plpgsql_check.show_nonperformance_warnings" = "true";
                  "plpgsql_check.show_performance_warnings" = "true";
                };

                initialScript = ''
                  create user ${PGUSER} with password '${PGPASSWORD}' superuser;
                  alter database ${PGDATABASE} owner to ${PGUSER};
                '';
              };
              enterShell = ''
                devenv up
              '';
            }];
          };

          default = pkgs.mkShell {
            packages = [supabase-cli] ++ (with pkgs; [
              nil
              sqls
              postgresql_15
              emacsPackages.vterm
              emacsPackages.sqlformat
            ]);

            env = {
              LOCALE_ARCHIVE =
                pkgs.lib.optionalString
                  pkgs.stdenv.isLinux
                  "${pkgs.glibcLocales}/lib/locale/locale-archive";
              LANG = "en_US.UTF-8";
              # https://www.postgresql.org/docs/current/libpq-envars.html
              PGHOSTADDR = PGHOSTADDR;
              PGUSER = PGUSER;
              PGDATABASE = PGDATABASE;
              PGPASSWORD = PGPASSWORD;
              PGPORT = PGPORT;
            };
          };
        });
      };
}
