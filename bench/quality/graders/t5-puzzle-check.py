# TASK-034 T5: brute-force check that the puzzle in prompts/t5-puzzle.txt has exactly one solution (prints it).
# Clue numbers match the prompt. Run: python3 bench/quality/graders/t5-puzzle-check.py
from itertools import permutations
names=["Ada","Bruno","Chiara","Dario","Elena"]
langs=["Rust","Go","TypeScript","Python","C"]
edit=["Vim","Emacs","VS Code","Zed","Helix"]
os_=["Linux","macOS","Windows","FreeBSD","ChromeOS"]
drink=["tea","coffee","water","juice","milk"]
sols=[]
P=list(permutations(range(5)))
for n in P:  # n[i] = desk of name i
    N=dict(zip(names,n))
    if N["Ada"]!=0: continue                        # 1 Ada sits at desk 1 (leftmost)
    if abs(N["Bruno"]-N["Elena"])!=1: continue      # 2 Bruno sits next to Elena
    for l in P:
        L=dict(zip(langs,l))
        if L["Rust"]!=N["Chiara"]: continue          # 3 Chiara writes Rust
        if L["Go"]!=L["TypeScript"]-1: continue      # 4 Go desk immediately left of TypeScript
        if L["Python"]==N["Dario"]: continue        # 5 Dario does not write Python
        for e in P:
            E=dict(zip(edit,e))
            if E["Vim"]!=L["C"]: continue            # 6 C programmer uses Vim
            if E["Emacs"]!=2: continue               # 7 middle desk uses Emacs
            if abs(E["Zed"]-L["Python"])!=1: continue # 8 Zed user next to Python
            if E["Helix"]==N["Ada"]: continue        # 9 Ada doesn't use Helix
            for o in P:
                O=dict(zip(os_,o))
                if O["macOS"]!=E["VS Code"]: continue # 10 VS Code on macOS
                if O["Linux"]!=N["Bruno"]: continue   # 11 Bruno on Linux
                if O["FreeBSD"]!=4: continue         # 12 rightmost desk FreeBSD
                if abs(O["Windows"]-L["Rust"])!=1: continue # 13 Windows next to Rust
                for d in P:
                    D=dict(zip(drink,d))
                    if D["coffee"]!=L["Go"]: continue     # 14 Go programmer drinks coffee
                    if D["tea"]!=N["Elena"]: continue     # 15 Elena drinks tea
                    if D["milk"]!=O["ChromeOS"]: continue # 16 ChromeOS user drinks milk
                    if abs(D["water"]-E["Helix"])!=1: continue # 17 water next to Helix
                    if D["juice"]==0: continue            # 18 desk 1 not juice
                    if D["milk"] in (0,4): continue        # 19 milk drinker not at an end
                    sols.append((N,L,E,O,D))
print(len(sols))
for s in sols:  # desk, name, language, editor, OS, drink
    for name,_ in sorted(s[0].items(), key=lambda kv: kv[1]):
        i=s[0][name]
        inv=lambda M:[k for k,v in M.items() if v==i][0]
        print(i+1,name,inv(s[1]),inv(s[2]),inv(s[3]),inv(s[4]))
    print()
