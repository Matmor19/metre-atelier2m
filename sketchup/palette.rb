# encoding: UTF-8
# Métré Atelier 2M : palette flottante (boutons espacés, animés au survol, regroupés par étape)
require 'sketchup.rb'
require 'json'

module A2M
  module Palette
    CLE = 'A2M_Metre_Palette'
    # Groupes de la palette : [titre, noms d'icônes]
    GROUPES = [
      ['Préparer',            %w[balises baliser pieces pieces_auto controle]],
      ['Dessiner',            %w[mur compose sol planelle toiture fondation hachures]],
      ['Ouvertures, finitions', %w[ouverture porte plinthe elec]],
      ['Bibliothèque',        %w[objet biblio profils]],
      ['Métré',               %w[extraire envoi aide]]
    ]

    def self.actions() ::ACTIONS_A2M end

    def self.html
      dico = File.join(File.dirname(__FILE__), 'icones')
      act = Hash[actions.map { |nom, titre, bulle, _a, _s| [nom, [titre, bulle]] }]
      blocs = GROUPES.map do |titre, noms|
        btns = noms.select { |n| act[n] }.map do |n|
          svg = File.read(File.join(dico, "#{n}.svg"), encoding: 'UTF-8') rescue ''
          t, b = act[n]
          "<button data-n=\"#{n}\"><span class=\"ic\">#{svg}</span><span class=\"lib\">#{t}</span><span class=\"bulle\">#{b.gsub('<', '&lt;')}</span></button>"
        end.join
        "<section><h2>#{titre}</h2><div class=\"grille\">#{btns}</div></section>"
      end.join
      <<~HTML
        <!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
        :root{--o:#E07838;--g:#3C3C3C;--f:#F6F3EF}
        *{box-sizing:border-box}
        body{margin:0;padding:10px 10px 4px;font:12px "Segoe UI",Arial,sans-serif;background:var(--f);color:var(--g);user-select:none;overflow-x:hidden}
        h2{font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;margin:6px 2px 6px;color:#8a7f75;font-weight:600}
        section{margin-bottom:8px}
        .grille{display:grid;grid-template-columns:repeat(auto-fill,minmax(46px,1fr));gap:10px}
        button{position:relative;border:0;background:transparent;padding:0;cursor:pointer;height:46px;border-radius:9px;outline:none}
        .ic{display:block;width:40px;height:40px;margin:3px auto;transition:transform .16s cubic-bezier(.3,1.6,.5,1),filter .16s,box-shadow .16s;border-radius:8px}
        .ic svg{width:40px;height:40px;display:block}
        button:hover .ic{transform:translateY(-3px) scale(1.14);filter:brightness(1.07);box-shadow:0 6px 12px rgba(224,120,56,.45)}
        button:active .ic{transform:translateY(0) scale(.94);box-shadow:0 1px 3px rgba(0,0,0,.3)}
        button.actif .ic{box-shadow:0 0 0 3px var(--g)}
        .lib,.bulle{display:none}
        #bulle{position:fixed;z-index:9;pointer-events:none;max-width:230px;background:var(--g);color:#fff;border-radius:7px;padding:7px 9px 8px;
          box-shadow:0 6px 16px rgba(0,0,0,.28);opacity:0;transform:translateY(4px);transition:opacity .12s,transform .12s}
        #bulle.vue{opacity:1;transform:translateY(0)}
        #bulle b{display:block;font-size:12px;color:var(--o);margin-bottom:2px}
        #bulle span{font-size:11.5px;line-height:1.35}
        #bulle:after{content:"";position:absolute;left:var(--fl,20px);border:6px solid transparent}
        #bulle.dessous:after{top:-12px;border-bottom-color:var(--g)}
        #bulle.dessus:after{bottom:-12px;border-top-color:var(--g)}
        #info{position:sticky;bottom:0;background:var(--f);border-top:1px solid #e2dbd3;padding:7px 2px 4px;min-height:52px}
        #info b{display:block;font-size:12.5px;margin-bottom:2px}
        #info span{color:#6f665e;font-size:11.5px;line-height:1.35}
        </style></head><body>
        #{blocs}
        <div id="bulle"></div>
        <div id="info"><b>Métré Atelier 2M</b><span>Survolez un bouton pour voir à quoi il sert, cliquez pour le lancer.</span></div>
        <script>
        var info=document.getElementById('info'), bulle=document.getElementById('bulle'), minu=null;
        // Bulle d'aide à côté du bouton survolé : sous le bouton, ou au-dessus s'il n'y a pas la place
        function montrer(b){
          var t='<b>'+b.querySelector('.lib').textContent+'</b><span>'+b.querySelector('.bulle').innerHTML+'</span>';
          info.innerHTML=t; bulle.innerHTML=t; bulle.className='';
          var r=b.getBoundingClientRect(), w=bulle.offsetWidth, h=bulle.offsetHeight, W=innerWidth, H=innerHeight;
          var x=Math.max(6,Math.min(W-w-6,r.left+r.width/2-w/2)), dessous=r.bottom+10+h<H-4;
          bulle.style.left=x+'px'; bulle.style.top=(dessous?r.bottom+10:r.top-h-10)+'px';
          bulle.style.setProperty('--fl',Math.max(8,Math.min(w-20,r.left+r.width/2-x-6))+'px');
          bulle.className=(dessous?'dessous':'dessus')+' vue';
        }
        document.querySelectorAll('button').forEach(function(b){
          b.addEventListener('mouseenter',function(){clearTimeout(minu);minu=setTimeout(function(){montrer(b)},250);});
          b.addEventListener('mouseleave',function(){clearTimeout(minu);bulle.className='';});
          b.addEventListener('click',function(){
            document.querySelectorAll('button.actif').forEach(function(x){x.classList.remove('actif')});
            b.classList.add('actif'); b.blur(); bulle.className=''; sketchup.lancer(b.dataset.n);
          });
        });
        </script></body></html>
      HTML
    end

    def self.ouvrir
      if @dlg && @dlg.visible?
        @dlg.bring_to_front
        return
      end
      @dlg = UI::HtmlDialog.new(dialog_title: 'Métré Atelier 2M', preferences_key: CLE, scrollable: true, resizable: true,
                                width: 300, height: 560, min_width: 140, min_height: 200, style: UI::HtmlDialog::STYLE_UTILITY)
      @dlg.set_html(html)
      @dlg.add_action_callback('lancer') do |_ctx, nom|
        a = actions.find { |x| x[0] == nom }
        # Le clavier revient à la fenêtre de dessin (longueurs tapées)
        UI.start_timer(0, false) do
          Sketchup.focus if Sketchup.respond_to?(:focus)
          a[3].call if a
        end
      end
      @dlg.set_on_closed { Sketchup.write_default(CLE, 'ouverte', false) unless @quitte }
      @dlg.show
      Sketchup.write_default(CLE, 'ouverte', true)
    end

    # Rouverte au démarrage si elle l'était à la fermeture de SketchUp
    def self.quitte!() @quitte = true end

    class Fin < Sketchup::AppObserver
      def onQuit() A2M::Palette.quitte! end
    end

    def self.au_demarrage
      Sketchup.add_observer(Fin.new)
      UI.start_timer(1, false) { ouvrir } if Sketchup.read_default(CLE, 'ouverte', false)
    end
  end
end
