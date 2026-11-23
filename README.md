# tl-cloud-infrastructure

The live cloud of the Trislab platform. It has the registers of tenants, products and domains in `catalog/`, the platform's own Azure resources, the landing zones, the environment stamps, the Cloudflare edge and the app repositories on GitHub. Each one is described by a file here and applied by the pipeline from a pull request, with `/apply` before the merge. The modules it pins come from `tl-platform`. Every product repository is created here, by an onboarding pull request. Start with [AGENTS.md](AGENTS.md): its Role section says what belongs here and where everything else goes.

## Licence

Proprietary: [LICENSE](LICENSE). The code is public to read, but it belongs to Trislab d.o.o., and only Trislab, and the clients of the applications Trislab delivers under a written agreement, may use it. Cloning or forking it for use, copying, redistribution and training AI models on it are not allowed. Material of others, such as the dependencies and a client's texts, logos and photos, keeps its owner's rights and its own licence.
