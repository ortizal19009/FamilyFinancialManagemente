import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-planning',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './planning.html',
  styleUrl: './planning.scss'
})
export class PlanningComponent implements OnInit {
  private apiService = inject(ApiService);

  planningData: any[] = [];
  categories: any[] = [];
  
  selectedMonth: number = new Date().getMonth() + 1;
  selectedYear: number = new Date().getFullYear();
  
  months = [
    { value: 1, name: 'Enero' }, { value: 2, name: 'Febrero' }, { value: 3, name: 'Marzo' },
    { value: 4, name: 'Abril' }, { value: 5, name: 'Mayo' }, { value: 6, name: 'Junio' },
    { value: 7, name: 'Julio' }, { value: 8, name: 'Agosto' }, { value: 9, name: 'Septiembre' },
    { value: 10, name: 'Octubre' }, { value: 11, name: 'Noviembre' }, { value: 12, name: 'Diciembre' }
  ];

  newPlan = {
    category_id: null,
    planned_amount: 0,
    month: this.selectedMonth,
    year: this.selectedYear
  };

  loading = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadCategories();
    this.loadPlanning();
  }

  loadCategories() {
    this.apiService.getCategories().subscribe(data => this.categories = data);
  }

  loadPlanning() {
    this.apiService.getPlanning(this.selectedMonth, this.selectedYear).subscribe(data => {
      this.planningData = data;
    });
  }

  onFilterChange() {
    this.loadPlanning();
    this.newPlan.month = this.selectedMonth;
    this.newPlan.year = this.selectedYear;
  }

  onSavePlan() {
    this.loading = true;
    this.apiService.savePlanning(this.newPlan).subscribe({
      next: () => {
        this.successMsg = 'Presupuesto guardado correctamente';
        this.loadPlanning();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al guardar el presupuesto';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  getProgressBarClass(planned: number, actual: number): string {
    const percentage = (actual / planned) * 100;
    if (percentage > 100) return 'bg-danger';
    if (percentage > 80) return 'bg-warning';
    return 'bg-success';
  }
}
