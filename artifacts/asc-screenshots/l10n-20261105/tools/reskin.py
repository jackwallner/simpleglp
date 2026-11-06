#!/usr/bin/env python3
"""Replace captures and CoreText headers in finished screenshot frames."""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

from common import config, destinations, erase_header, header_job, headline, paste_screen, raw_path, read_json, source


def extra_job(frame: dict, item: dict, text: str, locale: str) -> dict:
    return {
        'text': text,
        'locale': locale,
        'font': item['font'],
        'color': item['color'],
        'box': item['box'][2:],
        'maxSize': item.get('max_size', frame['max_size']),
        'minSize': item.get('min_size', 1),
        'align': item.get('align', 'center'),
    }


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--raw-root', type=Path, required=True)
    p.add_argument('--headers', type=Path, required=True)
    p.add_argument('--locale', required=True)
    p.add_argument('--out', type=Path, required=True, help='output root; writes ROOT/LOCALE/SET/file.png')
    p.add_argument('--set', dest='set_key')
    args = p.parse_args()
    data, headers = config(args.config), read_json(args.headers)[args.locale]
    sets = data['sets'] if args.set_key is None else {args.set_key: data['sets'][args.set_key]}
    plans = []
    for key, group in sets.items():
        frames = group['frames']
        jobs = [header_job(f, headers[f['file']], args.locale) for f in frames]
        results = headline(jobs)
        size = min(r['size'] for r in results)
        cause = frames[min(range(len(results)), key=lambda i: results[i]['size'])]
        for f, result in zip(frames, results):
            if not result['fits'] or size < f['min_size']:
                raise ValueError(f"{key}/{cause['file']}: size {size:g} below required minimum; text={headers[cause['file']]!r}")
            for target in destinations(f):
                if not raw_path(args.raw_root, args.locale, key, target['raw']).is_file():
                    raise ValueError(f"missing raw {key}/{target['raw']}")
        extra_plans = []
        for frame in frames:
            frame_extras = []
            for item in frame.get('extra_text', []):
                copy_key = f"{frame['file']}#{item['key']}"
                job = extra_job(frame, item, headers[copy_key], args.locale)
                result = headline([job])[0]
                if not result['fits'] or result['size'] < item.get('min_size', 1):
                    raise ValueError(
                        f"{key}/{copy_key}: size {result['size']:g} below required minimum; "
                        f"text={headers[copy_key]!r}"
                    )
                frame_extras.append((item, job, result))
            extra_plans.append(frame_extras)
        plans.append((key, group, jobs, size, extra_plans))
    with tempfile.TemporaryDirectory() as tmp:
        for key, group, jobs, size, extra_plans in plans:
            frames = group['frames']
            for i, job in enumerate(jobs):
                job.update(size=size, out=str(Path(tmp) / f'{i}.png'))
            all_jobs = list(jobs)
            for i, frame_extras in enumerate(extra_plans):
                for j, (_, job, result) in enumerate(frame_extras):
                    job.update(size=result['size'], out=str(Path(tmp) / f'{i}-extra-{j}.png'))
                    all_jobs.append(job)
            rendered = headline(all_jobs)
            if not all(r['fits'] for r in rendered):
                raise ValueError(f'{key}: uniform header size does not fit')
            output = args.out / args.locale / key
            output.mkdir(parents=True, exist_ok=True)
            for i, (frame, job) in enumerate(zip(frames, jobs)):
                with Image.open(source(data, frame['base'])) as im:
                    canvas = im.convert('RGB')
                if canvas.size != tuple(group['canvas']):
                    raise ValueError(f"{frame['file']}: base size differs from canvas")
                plate = None
                if frame.get('plate'):
                    with Image.open(source(data, frame['plate'])) as im:
                        plate = im.convert('RGB')
                erase_header(canvas, frame['header_box'], plate)
                for item, _, _ in extra_plans[i]:
                    erase_header(canvas, item['box'], plate)
                for target in destinations(frame):
                    with Image.open(raw_path(args.raw_root, args.locale, key, target['raw'])) as raw:
                        paste_screen(canvas, raw, target['rect'], target.get('radius', 0))
                with Image.open(job['out']) as overlay:
                    canvas.paste(overlay, tuple(frame['header_box'][:2]), overlay)
                for item, extra, _ in extra_plans[i]:
                    if item.get('fill_color'):
                        x, y, w, h = item['box']
                        ImageDraw.Draw(canvas).rounded_rectangle(
                            (x, y, x + w - 1, y + h - 1), radius=h / 2, fill=tuple(item['fill_color'])
                        )
                    with Image.open(extra['out']) as overlay:
                        canvas.paste(overlay, tuple(item['box'][:2]), overlay)
                canvas.save(output / frame['file'], format='PNG', optimize=True)
            print(f'{args.locale}/{key}: {len(frames)} frames size={size:g}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'reskin: {error}', file=sys.stderr)
        sys.exit(1)
