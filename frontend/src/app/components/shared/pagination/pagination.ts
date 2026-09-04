import { Component, input, output } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-pagination',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2" *ngIf="totalPages() > 1">
      <span class="small text-muted">
        Página {{ page() }} de {{ totalPages() }} · {{ totalItems() }} registros
      </span>
      <div class="d-flex gap-2">
        <button class="btn btn-sm btn-light border small" [disabled]="page() <= 1" (click)="goToPage(page() - 1)">
          <i class="bi bi-chevron-left me-1"></i> Anterior
        </button>
        <button class="btn btn-sm btn-light border small" [disabled]="page() >= totalPages()" (click)="goToPage(page() + 1)">
          Siguiente <i class="bi bi-chevron-right ms-1"></i>
        </button>
      </div>
    </div>
  `
})
export class AppPaginationComponent {
  page = input(1);
  totalPages = input(0);
  totalItems = input(0);
  pageChange = output<number>();

  goToPage(target: number) {
    if (target < 1 || target > this.totalPages() || target === this.page()) {
      return;
    }
    this.pageChange.emit(target);
  }
}