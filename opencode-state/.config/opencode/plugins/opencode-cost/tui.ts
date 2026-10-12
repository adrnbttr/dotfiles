import { Plugin } from "@opencode/plugin/tui"

// Affiche le cout de la session courante, un taux $/h, et le total du jour.
// Declenchement : slash `/cost` (ou /cout /prix) ou racourci ctrl+shift+c.

export default Plugin.define({
  id: "opencode-cost",
  setup(context) {
    const money = (n: unknown) => "$" + (Number(n) || 0).toFixed(4)
    const t0 = new Date()
    t0.setHours(0, 0, 0, 0)
    const dayStart = t0.getTime()

    function report() {
      try {
        const sessions = (context.data.session.list() as any[]) ?? []
        if (!sessions.length) {
          context.ui.dialog.alert({ title: "Cout", message: "Aucune session sur cette location." })
          return
        }
        const sorted = [...sessions].sort((a, b) => (b?.time?.updated ?? 0) - (a?.time?.updated ?? 0))
        const s: any = sorted[0]
        const cost = Number(context.data.session.cost(s.id)) || 0
        const created = s?.time?.created ?? Date.now()
        const hours = Math.max((Date.now() - created) / 3.6e6, 1 / 3600)
        const rate = cost / hours

        const today = sessions.filter((x: any) => (x?.time?.created ?? 0) >= dayStart)
        let dayTotal = 0
        for (const x of today) dayTotal += Number(context.data.session.cost(x.id)) || 0

        const title = (s?.title ?? s.id) as string
        const lines = [
          "Session : " + title.slice(0, 48),
          "Cout    : " + money(cost) + "   (taux " + money(rate) + "/h sur " + hours.toFixed(2) + " h)",
          "",
          "Aujourd'hui : " + money(dayTotal) + " sur " + today.length + " session(s)",
          "",
          "Detail complet : ococ",
        ]
        context.ui.dialog.alert({ title: "Cout de session", message: lines.join("\n") })
      } catch (err) {
        context.ui.toast.show({ title: "opencode-cost", message: "erreur : " + String(err), variant: "error" })
      }
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "opencode.cost",
          title: "Cout de session (+ taux horaire)",
          bind: "ctrl+shift+c",
          palette: true,
          slash: { name: "cost", aliases: ["cout", "prix"] },
          run: () => report(),
        },
      ],
      bindings: ["opencode.cost"],
    }))
  },
})
