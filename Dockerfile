# kcl — full CLI from kcl-lang/cli (Go). The kclvm_cli from kcl-lang/kcl
# releases is a minimal build (only run/server/version, no kpm package
# management): `kcl run` on modules with kcl.mod deps fails with
# CannotFindModule. Version matches the ArgoCD CMP image ghcr.io/metacoma/kcl-vals.
RUN curl -fsSL https://github.com/kcl-lang/cli/releases/download/${KCL_VERSION}/kcl-${KCL_VERSION}-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin kcl \
    && chmod +x /usr/local/bin/kcl \
    && kcl version || true

# kcl-language-server — not shipped in the cli release; comes from the kclvm
# runtime tarball. kclvm_cli stays in /opt/kclvm/bin (minimal fallback), NOT linked as kcl.
RUN curl -fsSL https://github.com/kcl-lang/kcl/releases/download/${KCL_VERSION}/kclvm-${KCL_VERSION}-linux-amd64.tar.gz \
    | tar -xz -C /opt \
    && ln -sf /opt/kclvm/bin/kcl-language-server /usr/local/bin/kcl-lsp