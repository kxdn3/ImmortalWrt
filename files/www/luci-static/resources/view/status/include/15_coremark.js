'use strict';
'require baseclass';
'require uci';

return baseclass.extend({
    title: _('CoreMark 跑分'),

    load: function() {
        return uci.load('coremark');
    },

    render: function() {
        var score = uci.get('coremark', 'result', 'score');
        var ts = uci.get('coremark', 'result', 'timestamp');

        var body;
        if (score) {
            body = [
                E('div', { style: 'font-size:1.3em;font-weight:bold' }, score),
                E('div', { style: 'font-size:85%;opacity:.7' }, _('上次运行：%s').format(ts))
            ];
        } else {
            body = E('em', {}, _('尚未跑分，将于凌晨 5:00 自动执行'));
        }

        return E('div', { class: 'ifacebox' }, [
            E('div', { class: 'ifacebox-head' }, _('CoreMark 跑分')),
            E('div', { class: 'ifacebox-body center' }, body)
        ]);
    }
});
