"""Kampüs kelimesi sözlüğü: zemberek-nlp `master-dictionary.dict` dosyasından 4-8 harfli Türkçe kelimeleri ayıklar
ve `private.word_dictionary`'yi dolduran migration SQL'ini yazar.

Kaynak: https://github.com/ahmetaa/zemberek-nlp (morphology/src/main/resources/tr/master-dictionary.dict),
Apache License 2.0 (docs/UCUNCU_TARAF.md). Yalnızca kök kelimeler var (çekimli biçimler yok); özel adlar,
kısaltmalar ve noktalama alınmaz; şapkalı harfler düzleştirilir (â → a); Türkçe büyük harfe çevrilir (i → İ).

Kullanım: python -I supabase/sozluk/sozluk_migration.py <master-dictionary.dict> <çıktı.sql>
"""
import collections
import sys

LOWER = 'abcçdefgğhıijklmnoöprsştuüvyz'
UPPER = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ'
TO_UPPER = str.maketrans(LOWER, UPPER)
FOLD = str.maketrans({'â': 'a', 'î': 'i', 'û': 'u'})
SKIP_TAGS = ('Prop', 'Abbrv', 'Punc', 'Dup')


def words_from(path):
    words = set()
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        word, _, attrs = line.partition(' ')
        if any(tag in attrs for tag in SKIP_TAGS) or word[:1].isupper():
            continue
        w = word.translate(FOLD)
        if w and all(c in LOWER for c in w) and 4 <= len(w) <= 8:
            words.add(w.translate(TO_UPPER))
    return sorted(words)


def main():
    src, out = sys.argv[1], sys.argv[2]
    words = words_from(src)
    counts = collections.Counter(len(w) for w in words)
    lines, line = [], ''
    for w in words:
        if len(line) + len(w) + 1 > 116:
            lines.append(line)
            line = ''
        line = f'{line} {w}' if line else w
    lines.append(line)
    body = '\n'.join(lines)
    summary = ', '.join(f'{n} harf {c}' for n, c in sorted(counts.items()))
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write(
            '-- Adım 19: Kampüs kelimesi sözlüğü (tahminler bu listede olmalı ya da günün kelimesinin kendisi olmalı).\n'
            '-- Kaynak: zemberek-nlp master-dictionary.dict (Apache License 2.0, docs/UCUNCU_TARAF.md); üreten\n'
            '-- supabase/sozluk/sozluk_migration.py. Yalnızca kök kelimeler, 4-8 harf, Türkçe büyük harf.\n'
            f'-- {len(words)} kelime ({summary}).\n\n'
            'insert into private.word_dictionary (word)\n'
            "select w from regexp_split_to_table($sozluk$\n"
            f'{body}\n'
            "$sozluk$, '\\s+') w\n"
            "where w <> ''\n"
            'on conflict do nothing;\n'
        )
    print(len(words), summary)


if __name__ == '__main__':
    main()
